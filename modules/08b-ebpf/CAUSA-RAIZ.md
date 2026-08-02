# Causa raíz — Módulo 08b

> Solo después de haber escrito tu diagnóstico.

## 1. Por qué tu observabilidad no lo ve

Una conexión TCP atraviesa esto antes de que tu código la toque:

```
SYN llega
  → cola SYN (半-abiertas)         ← tcp_max_syn_backlog
  → handshake completo
  → cola de accept (establecidas)  ← min(backlog de listen(), somaxconn)
  → la aplicación llama a accept()
  → ★ AQUÍ empieza tu span ★
  → handler
  → respuesta
```

Tus trazas y tus métricas de aplicación empiezan en la estrella. Todo el tiempo
que la conexión pasó esperando en la cola de accept es **invisible** para ellas:
para tu aplicación, la petición acaba de llegar y la sirve en 43 ms, que es
exactamente lo que reporta.

No es un fallo de configuración. Es un límite estructural de la instrumentación
en espacio de usuario: **no puedes instrumentar lo que ocurre antes de que tu
proceso participe.**

Por eso el p99 de `$request_time` en el borde es de 4,2 s: NGINX sí mide desde
que abre la conexión, incluida la espera.

## 2. `ListenOverflows` y `ListenDrops`

- **`ListenOverflows`**: llegó un ACK que completaba un handshake, pero la cola
  de accept estaba llena. El kernel **descarta** la conexión.
- **`ListenDrops`**: contador más amplio de conexiones descartadas en el socket
  en LISTEN; aquí coincide con el anterior, lo que confirma que la causa son los
  desbordamientos.

Qué le pasa al cliente: con `tcp_abort_on_overflow=0` (por defecto), el kernel
**ignora el ACK en silencio**. El cliente cree que la conexión está establecida y
espera. Al no recibir respuesta, retransmite — de ahí los 392 `TCPSynRetrans`.
El primer reintento es al segundo, el siguiente a los 3 s, luego a los 7 s.

**Ahí están tus 4,2 segundos.** No es lentitud: es un cliente esperando un
temporizador de retransmisión TCP porque su conexión se tiró a la basura.

Es un modo de fallo especialmente cruel porque el sistema parece sano: el kernel
descarta la conexión sin registrar nada visible en la aplicación.

## 3. Verlo en vivo

```bash
# Cola de accept de un socket en LISTEN.
# En LISTEN, Recv-Q = conexiones establecidas esperando accept()
#            Send-Q = tamaño máximo de esa cola
ss -ltn
# State  Recv-Q Send-Q  Local Address:Port
# LISTEN 128    128     0.0.0.0:8080      ← llena: Recv-Q == Send-Q

# Contadores, con delta en vez de acumulado
nstat -az | grep -iE 'listenoverflow|listendrop|synretrans'
watch -n1 'nstat | grep -i listen'
```

Con bpftrace, viéndolo ocurrir:

```bash
# Cada vez que se descarta una conexión por cola llena
bpftrace -e '
kprobe:tcp_v4_syn_recv_sock { @attempts = count(); }
tracepoint:tcp:tcp_retransmit_skb { @retrans[comm] = count(); }
interval:s:5 { print(@attempts); print(@retrans); clear(@attempts); clear(@retrans); }'

# Latencia de accept: cuánto espera una conexión en la cola
bpftrace -e '
kprobe:inet_csk_accept { @start[tid] = nsecs; }
kretprobe:inet_csk_accept /@start[tid]/ {
  @accept_latency_us = hist((nsecs - @start[tid]) / 1000);
  delete(@start[tid]);
}'
```

Ese histograma es la métrica que tu aplicación **no puede** producir sobre sí
misma.

## 4. Los dos parámetros

### a) El `backlog` que pide la aplicación

En Go, `net.Listen` usa por defecto el valor de `somaxconn`, así que aquí el
problema no es el código — pero en otros lenguajes y en NGINX sí se pide
explícitamente (`listen 443 backlog=N`).

### b) `net.core.somaxconn` — el techo del kernel

**Este es el que muerde.** Aunque la aplicación pida 4096, el kernel recorta al
valor de `somaxconn` **en silencio**. Sin error, sin aviso, sin log.

```bash
# Dentro del pod
sysctl net.core.somaxconn
# net.core.somaxconn = 128       ← el techo real
```

En Linux moderno el valor por defecto es 4096, pero muchas imágenes base,
runtimes de contenedor y nodos gestionados siguen arrancando con 128 heredado.

**Hacen falta los dos cambios**: subir el techo del kernel *y* que la aplicación
pida un backlog mayor. Cambiar solo uno no sirve — es el mismo patrón que
`allowedRoutes` y `ReferenceGrant` del módulo 05: dos controles independientes
que hay que satisfacer a la vez.

```yaml
# En el pod, vía securityContext
securityContext:
  sysctls:
    - name: net.core.somaxconn
      value: "4096"
    - name: net.ipv4.tcp_max_syn_backlog
      value: "4096"
```

`net.core.somaxconn` es un sysctl *no seguro* en muchas versiones de Kubernetes,
así que puede requerir habilitarlo en el kubelet (`--allowed-unsafe-sysctls`).
Que sea incómodo es parte de la lección: la respuesta correcta no siempre es la
cómoda.

## 5. La observabilidad que faltaba

Tres capas, de más barata a más cara:

```promql
# a) node-exporter ya expone esto. Nadie lo mira.
rate(node_netstat_TcpExt_ListenOverflows[5m]) > 0
```

Una sola alerta habría convertido esto en una notificación en vez de en una
investigación. **El dato ya estaba ahí.**

```promql
# b) Retransmisiones, como señal de acompañamiento
rate(node_netstat_Tcp_RetransSegs[5m]) / rate(node_netstat_Tcp_OutSegs[5m]) > 0.02
```

c) Y la buena: un exporter basado en eBPF que publique el histograma de latencia
de `accept()` como métrica de Prometheus. Es lo que construyes en el lab 04.

## 6. Por qué el módulo 02 no bastaba

Allí aprendiste la regla correcta: `$request_time` alto con
`$upstream_response_time` bajo significa que el tiempo se fue **fuera de tu
backend**. Y es cierto.

Lo que no sabías entonces es que "fuera de tu backend" no significa solo "en el
cliente o en la red". Incluye la pila TCP de tu propio servidor — un sitio que
está literalmente dentro de tu máquina y aun así fuera del alcance de cualquier
instrumentación que pongas en tu código.

**La lección:** cada capa de observabilidad tiene un suelo. La instrumentación de
aplicación tiene el suyo en `accept()`. Debajo de ese suelo necesitas otras
herramientas, y este módulo es esas herramientas.
