# Break-fix — Módulo 08b

## El escenario

Los clientes reportan que Pulse va lento. Picos de varios segundos, de forma
intermitente, sobre todo en horas punta.

Miras todo lo que construiste en los módulos 07 y 08:

**Métricas de aplicación** — el handler es rápido:

```
histogram_quantile(0.99, sum by (le) (rate(pulse_http_request_duration_seconds_bucket[5m])))
→ 0.043
```

43 milisegundos en el p99. Sin degradación.

**Trazas** — el span raíz de `pulse-api` dura 41 ms. El span hijo de Postgres,
6 ms. No hay huecos en la cascada. La traza está completa y es rápida.

**Recursos** — CPU al 30%, memoria al 45%, sin OOMKills, sin reinicios,
sin throttling de CFS.

**El borde** — y aquí está lo raro:

```
$request_time          p99 = 4.2s
$upstream_response_time p99 = 0.051s
```

Ya viste esta forma en el módulo 02 y concluiste "cliente lento o red". Pero esta
vez los clientes están dentro de la misma región, con buen ancho de banda, y las
respuestas son de 4 KB. No es un cliente lento.

**Y el dato que no encaja:**

```
$ kubectl exec -n pulse deploy/pulse-api -- cat /proc/net/netstat | grep -A1 TcpExt
$ nstat -az | grep -iE 'listendrop|listenoverflow|retrans'
TcpExtListenOverflows           1847
TcpExtListenDrops               1847
TcpExtTCPSynRetrans             392
```

## Tu trabajo

1. Explica por qué **ninguna** de tus métricas ni trazas ve este problema. No es
   que estén mal configuradas.
2. ¿Qué significan `ListenOverflows` y `ListenDrops`? ¿Qué le pasa exactamente a
   una conexión que cae ahí?
3. Diagnostícalo con eBPF: qué programa escribirías o qué herramienta usarías
   para observarlo en vivo, y qué esperas ver.
4. Hay **dos** parámetros que hay que corregir, en dos sitios distintos, y hace
   falta cambiar los dos. Encuéntralos.
5. Añade la observabilidad que faltaba, para que la próxima vez esto sea una
   alerta y no una investigación.
6. ¿Por qué el módulo 02 te enseñó a leer esta señal y aun así no bastaba?

## Pistas escalonadas

<details><summary>Pista 1</summary>

Tus trazas empiezan cuando la aplicación **acepta** la conexión. ¿Qué le pasa al
tiempo que una conexión espera *antes* de ser aceptada? ¿Quién lo mide?
</details>

<details><summary>Pista 2</summary>

Hay dos colas entre un `SYN` que llega y un `accept()` que devuelve: la de
peticiones a medio establecer y la de conexiones ya establecidas esperando a que
la aplicación las recoja. `ListenOverflows` cuenta desbordamientos de una de
ellas. ¿De cuál?
</details>

<details><summary>Pista 3 — para el punto 4</summary>

Uno de los parámetros lo pide la aplicación al llamar a `listen()`. El otro es un
límite del kernel que **recorta** al primero silenciosamente si es mayor. Pedir
4096 con el techo del kernel en 128 te deja con 128, sin ningún error.
</details>

<details><summary>Pista 4 — para el punto 3</summary>

`bpftrace` puede engancharse a puntos de traza del kernel. Busca
`tcp:tcp_retransmit_skb`, y `kprobe:tcp_v4_syn_recv_sock`. También sirve
`ss -ltn`, donde las columnas `Recv-Q` y `Send-Q` en un socket en LISTEN
significan algo distinto de lo que significan en uno establecido — averigua qué.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Es el caso que justifica el módulo entero. Instrumentaste todo el código y aun
así el problema es invisible, porque **ocurre antes de que tu código exista para
la petición**. Ninguna cantidad de spans lo habría revelado.

Y cierra el arco del módulo 02: allí aprendiste que `$request_time` alto con
`$upstream_response_time` bajo apunta fuera de tu backend. Correcto — pero
"fuera" incluía un sitio que entonces no sabías mirar.
