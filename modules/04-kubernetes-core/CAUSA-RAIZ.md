# Causa raíz — Módulo 04

> Solo después de haber escrito tu diagnóstico.

## Bug 1 — la readiness probe apunta al endpoint equivocado

```yaml
readinessProbe:
  httpGet:
    path: /healthz     # ← responde 200 en cuanto el servidor HTTP escucha
```

`/healthz` es un endpoint de **liveness**: responde "el proceso está vivo".
`/readyz` es el de **readiness**: responde "puedo atender tráfico", y devuelve
503 durante los primeros 2 segundos mientras la aplicación completa su arranque.

Al apuntar la readiness probe a `/healthz`, el kubelet marca el pod como `Ready`
en cuanto el servidor HTTP acepta conexiones. El endpoints controller lo añade
inmediatamente al Service. El kube-proxy empieza a mandarle tráfico.

Durante los siguientes ~2 segundos, ese pod responde **503 a todo**.

Y aquí está lo que hace el diagnóstico difícil: para Kubernetes no hay ningún
fallo. El pod está vivo, está listo (según lo que le preguntaste), y no reinicia.
`kubectl get pods` dice `1/1 Running 0 restarts` y es literalmente cierto.

### Distinción que hay que tener clara

| Probe | Pregunta | Fallo → consecuencia |
|---|---|---|
| **startup** | ¿Ha terminado de arrancar? | Reinicia el contenedor. Desactiva las otras dos mientras corre |
| **liveness** | ¿Sigue vivo o está colgado? | **Reinicia el contenedor** |
| **readiness** | ¿Puede atender tráfico ahora? | **Lo saca de los Endpoints.** No reinicia |

Confundir liveness con readiness es confundir "matar el proceso" con "dejar de
mandarle tráfico". Son respuestas opuestas al mismo síntoma.

## Bug 2 — `maxSurge: 3` con `maxUnavailable: 0`

```yaml
maxSurge: 3
maxUnavailable: 0
```

Con 3 réplicas, `maxSurge: 3` crea **los tres pods nuevos a la vez**. Los tres
pasan su readiness probe (falsa) simultáneamente, los tres entran en los
Endpoints a la vez, y los tres están no-listos a la vez.

Durante esos 2 segundos, el Service tiene 6 endpoints: 3 viejos sanos y 3 nuevos
que devuelven 503. Aproximadamente la mitad del tráfico va a los rotos.

**El cálculo del punto 2:** despliegue de ~12 s, 2 s con la mitad de los
endpoints fallando ≈ 2/12 × 50% ≈ 8%. Sumando el cierre de los pods viejos (bug
3, abajo), llegas al 15% observado. Que el número cuadre es la confirmación de
que el diagnóstico es correcto y no una historia plausible.

Con `maxSurge: 1` el daño se reparte: solo un endpoint de cuatro está roto en
cada momento, ~12% de un tercio del tiempo.

`maxUnavailable: 0` no es el problema —es correcto y deseable—, pero combinado
con un surge alto concentra todo el riesgo en un instante.

## Bug 3 — el `preStop` que no está

Cuando un pod viejo se termina, ocurren dos cosas **en paralelo, sin orden
garantizado**:

1. El kubelet manda `SIGTERM` al contenedor.
2. El endpoints controller lo saca del Service.

El (2) se propaga a través del API server, el endpoints controller y cada
kube-proxy de cada nodo. Eso tarda. Durante esa ventana, el pod ya está
apagándose y sigue recibiendo tráfico nuevo.

`pulse-api` maneja `SIGTERM` correctamente (lo hiciste en el módulo 01), pero eso
no ayuda: deja de aceptar conexiones justo cuando kube-proxy todavía se las
manda.

El arreglo es contraintuitivo:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sleep", "5"]
```

Un `sleep` que no hace nada. Su función es **retrasar el `SIGTERM`** lo
suficiente para que la eliminación del endpoint se propague. El pod sigue
sirviendo con normalidad durante ese tiempo.

## Bug 4 — la liveness probe latente

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 10
  # timeoutSeconds: 1        ← por defecto
  # failureThreshold: 3      ← por defecto
```

`timeoutSeconds: 1` por defecto. Si bajo carga la aplicación tarda más de 1 s en
responder a `/healthz`, la probe falla. Tres fallos consecutivos (30 s) y el
kubelet **reinicia el contenedor**.

Ese contenedor no estaba roto: estaba ocupado. Al reiniciarlo, su carga se
reparte entre los pods restantes, que ahora van más lentos, y sus probes empiezan
a fallar. **Reinicio en cascada bajo carga**, provocado por el mecanismo diseñado
para proteger el servicio.

Regla: la liveness probe debe detectar *colgado*, no *lento*. Debe ser barata, no
tocar dependencias, y tener umbrales generosos. Ante la duda, no pongas liveness
probe — un servicio sin liveness probe se degrada; uno con una liveness probe
agresiva se cae.

## El manifiesto corregido

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: pulse-api
          image: ghcr.io/example/pulse-api@sha256:...   # módulo 03: por digest
          ports:
            - containerPort: 8080

          startupProbe:
            httpGet: { path: /healthz, port: 8080 }
            periodSeconds: 2
            failureThreshold: 15          # 30s de margen para arrancar

          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            periodSeconds: 15
            timeoutSeconds: 5             # generoso a propósito
            failureThreshold: 3

          readinessProbe:
            httpGet: { path: /readyz, port: 8080 }   # ← el endpoint correcto
            periodSeconds: 3
            timeoutSeconds: 2
            failureThreshold: 2

          lifecycle:
            preStop:
              exec:
                command: ["sleep", "5"]
```

La `startupProbe` permite además relajar `initialDelaySeconds` en las otras dos:
mientras la startup corre, las demás están desactivadas, así que un arranque
lento no puede provocar un reinicio.

## La prueba

```bash
# Carga constante durante un despliegue
while :; do
  curl -s -o /dev/null -w '%{http_code}\n' http://pulse.local/api/checks
  sleep 0.05
done > /tmp/codes.txt &

kubectl set image deployment/pulse-api pulse-api=...:v1.4.3 -n pulse
kubectl rollout status deployment/pulse-api -n pulse
kill %1

sort /tmp/codes.txt | uniq -c
# Antes: ~15% no-200. Después: 0.
```

Ese contador es la evidencia que va al README del módulo. "Arreglé las probes" no
es un resultado; "de 15% de errores por despliegue a 0, medido" sí lo es.
