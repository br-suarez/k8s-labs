# Preguntas de entrevista — Módulo 04

## Probes y ciclo de vida

**1. Las tres probes: qué pregunta responde cada una y qué pasa cuando falla.**

<details><summary>Guía</summary>

Startup: "¿ha terminado de arrancar?" → reinicia, y desactiva las otras dos
mientras corre. Liveness: "¿está colgado?" → reinicia el contenedor. Readiness:
"¿puede servir?" → lo saca de los Endpoints, sin reiniciar. El error clásico es
apuntar la readiness a un endpoint de liveness, con lo que el pod recibe tráfico
antes de estar listo.
</details>

**2. ¿Cuándo es correcto NO poner liveness probe?**

<details><summary>Guía</summary>

Casi siempre, si no puedes nombrar un modo de fallo concreto en el que el
proceso quede vivo pero permanentemente inútil y del que se recupere
reiniciando. Una liveness probe mal ajustada convierte lentitud en reinicios, y
bajo carga eso cascada. Un servicio sin liveness se degrada; uno con liveness
agresiva se cae.
</details>

**3. ¿Por qué un `preStop` con `sleep 5` arregla los 502 durante un rollout, si
la aplicación ya maneja SIGTERM correctamente?**

<details><summary>Guía</summary>

Porque el `SIGTERM` y la eliminación del endpoint ocurren en paralelo y sin
orden garantizado. La eliminación tiene que propagarse por el API server, el
endpoints controller y cada kube-proxy; mientras tanto el pod ya está cerrando.
El `sleep` retrasa el SIGTERM lo justo para que la propagación termine. Es
contraintuitivo y por eso se pregunta.
</details>

## Scheduling

**4. Un pod lleva 5 minutos `Pending`. Tres clases de causa y cómo las
distingues.**

<details><summary>Guía</summary>

(a) Sin recursos: ningún nodo tiene CPU/memoria suficiente. (b) Restricciones de
scheduling: taints sin toleration, nodeSelector o affinity sin candidatos,
anti-affinity que se auto-bloquea. (c) Volúmenes: PVC sin bind, o un PV en otra
zona. `kubectl describe pod` lo dice en los eventos, y el mensaje del scheduler
nombra cuántos nodos descartó y por qué motivo cada uno — leer ese desglose es la
respuesta.
</details>

**5. Requests vs limits, y las tres clases de QoS.**

<details><summary>Guía</summary>

Requests: lo que el scheduler reserva. Limits: el techo que impone el runtime.
`Guaranteed` = requests iguales a limits en todos los contenedores.
`Burstable` = tiene requests, menores que los limits. `BestEffort` = sin
ninguno. En caso de presión de memoria el kubelet expulsa primero BestEffort,
luego Burstable que exceda su request, y Guaranteed al final. Detalle importante:
superar el limit de memoria mata el contenedor (OOMKill), superar el de CPU solo
lo throttlea.
</details>

**6. ¿Por qué poner un limit de CPU puede empeorar la latencia de un servicio que
nunca lo alcanza?**

<details><summary>Guía</summary>

El throttling de CFS opera por cuotas de 100 ms. Una aplicación con picos cortos
puede agotar su cuota a mitad de periodo y quedar parada hasta el siguiente,
aunque su uso medio esté muy por debajo del limit. Se ve en
`container_cpu_cfs_throttled_seconds_total`. Es un argumento real para omitir
los limits de CPU y quedarse solo con requests — postura defendible y que
conviene saber sostener.
</details>

## Red y Services

**7. Deployment `3/3 READY`, el Service devuelve 503 intermitente, port-forward a
cada pod funciona. ¿Qué pasa?**

<details><summary>Guía</summary>

El port-forward salta el Service, así que prueba el pod, no el enrutado. Causas:
el selector del Service coincide con pods de otro ReplicaSet o de otra versión;
readiness que pasa antes de tiempo (este módulo); `publishNotReadyAddresses:
true`; o un `targetPort` que no corresponde al puerto real. `kubectl get
endpoints` es el primer comando — muestra exactamente qué IPs hay detrás.
</details>

**8. `no matches for kind "HorizontalPodAutoscaler" in version
"autoscaling/v2beta2"`. ¿Qué pasó?**

<details><summary>Guía</summary>

Esa versión de API fue eliminada en Kubernetes 1.26. No está deprecada: no
existe. El arreglo es migrar a `autoscaling/v2`, que no es solo cambiar la cadena
—la estructura de `metrics` cambió. Contexto útil: `kubectl convert`, y
`kubectl get --raw /metrics` para detectar uso de APIs deprecadas antes de
actualizar un cluster.
</details>

## Trade-offs

**9. `maxSurge` y `maxUnavailable`: cómo los elegirías para un servicio con
tráfico constante y para un job por lotes.**

<details><summary>Guía</summary>

Servicio con tráfico: `maxUnavailable: 0` para no perder capacidad, y `maxSurge`
bajo (1, o un 25%) para que el riesgo del despliegue se reparta en vez de
concentrarse. Requiere capacidad de sobra en el cluster. Por lotes o con recursos
escasos: `maxSurge: 0` y `maxUnavailable` alto — se acepta indisponibilidad a
cambio de no necesitar capacidad extra. El error de este módulo es surge alto con
una readiness que miente, que concentra todo el fallo en un instante.
</details>
