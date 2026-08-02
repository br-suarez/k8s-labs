# Preguntas de entrevista — Módulo 08

## Conceptos

**1. Las tres señales de OTel y qué las une.**

<details><summary>Guía</summary>

Trazas, métricas y logs. Las une el **Resource**: un conjunto de atributos
(`service.name`, `service.version`, `k8s.pod.name`…) adjunto a todas las señales
que emite un proceso. Eso es lo que permite saltar de una métrica a las trazas
del mismo servicio. La segunda pieza son los **exemplars**, que enlazan un punto
concreto de un histograma con un trace ID.
</details>

**2. ¿Qué es el context propagation y cuál es el formato por defecto?**

<details><summary>Guía</summary>

Pasar el trace ID y el span ID del padre a través de un límite de proceso para
que el hijo se una a la misma traza. El estándar es W3C Trace Context, cabecera
`traceparent`: `00-<trace-id 32 hex>-<parent-id 16 hex>-<flags 2 hex>`. El último
byte lleva el flag de sampled, que es cómo la decisión de muestreo viaja con la
petición. Existe también `tracestate` para información específica de vendor.
</details>

**3. `pulse-api` encola un trabajo; `pulse-worker` lo recoge 40 s después. ¿Por
qué se rompe la traza?**

<details><summary>Guía</summary>

Porque no hay conexión viva por la que viajen las cabeceras. El worker arranca
con un contexto vacío y crea una traza nueva y huérfana. Hay que **serializar el
contexto en el payload del trabajo** (inyectarlo con el propagador al encolar) y
restaurarlo al desencolar. Además, la relación correcta no siempre es
padre-hijo: si el productor ya terminó, lo apropiado es un **span link**, no un
parent. Saber cuándo usar link en vez de parent es lo que distingue haber leído
la spec de haberla aplicado.
</details>

## Muestreo

**4. Head vs tail sampling. Un requisito que solo cumple el segundo.**

<details><summary>Guía</summary>

Head decide al inicio de la traza, antes de saber qué va a pasar: barato, sin
estado, y la decisión se propaga con `traceparent`. Tail decide al final, con la
traza completa: puede quedarse con todos los errores y todo lo lento. Requisito
que solo cumple tail: "quiero el 100% de las trazas con error y el 1% del resto".
Con head no es posible, porque cuando decides todavía no sabes si habrá un error.
El coste de tail es que el Collector debe **almacenar en memoria** las trazas
mientras espera a que se completen, lo que lo convierte en stateful y complica
escalarlo horizontalmente.
</details>

**5. Tienes tail sampling y dos réplicas del Collector. ¿Qué se rompe?**

<details><summary>Guía</summary>

Los spans de una misma traza pueden llegar a réplicas distintas, y ninguna ve la
traza completa, así que la decisión se toma sobre datos parciales. Se resuelve
con una capa previa de Collectors en modo balanceo que enruta por trace ID
(`loadbalancing` exporter), de forma que todos los spans de una traza acaben en
la misma instancia. Es la complicación operativa principal del tail sampling y la
razón por la que mucha gente se queda en head.
</details>

## El Collector

**6. Receivers, processors, exporters. ¿Por qué el orden de los processors
importa?**

<details><summary>Guía</summary>

Se ejecutan en secuencia sobre cada lote. `memory_limiter` **debe ir primero**:
protege de lo que viene detrás de él, así que ponerlo después de `batch`
significa que `batch` ya acumuló miles de spans en memoria antes de que el
limitador pudiera decir nada. Es un error de configuración muy común y es el
defecto del break-fix de este módulo.
</details>

**7. `sending_queue` está al 100%. ¿Qué pasa con los spans nuevos y cómo evitas
perderlos?**

<details><summary>Guía</summary>

Se descartan, y se cuenta en `otelcol_exporter_enqueue_failed_spans`. La cola es
en memoria por defecto, así que además un reinicio del Collector la pierde
entera. Se mitiga con la extensión `file_storage` como backing store de la cola,
subiendo `queue_size`, y sobre todo reduciendo el volumen aguas arriba con
muestreo. Pero lo importante es alertar sobre ello: una cola llena es pérdida
silenciosa de datos.
</details>

**8. ¿Por qué desplegar el Collector como sidecar, como DaemonSet o como
Deployment? Un caso para cada uno.**

<details><summary>Guía</summary>

Sidecar: aislamiento por aplicación, la latencia de exportación no se comparte,
útil en multi-tenant; coste, una instancia por pod. DaemonSet: uno por nodo,
recoge también telemetría del nodo, buen equilibrio para el enriquecimiento con
metadatos de Kubernetes. Deployment (gateway): pool central, necesario para tail
sampling con enrutado por trace ID y para aplicar políticas de forma consistente.
El patrón habitual en producción es DaemonSet como agente **más** un gateway
detrás.
</details>

## Correlación

**9. Estás mirando un pico de latencia en Grafana. ¿Cómo llegas a la traza
concreta?**

<details><summary>Guía</summary>

Exemplars. El histograma de Prometheus guarda, por bucket, un ejemplo con su
trace ID y su timestamp. Grafana lo pinta como un punto sobre el gráfico y
enlaza a Tempo. Requiere: exemplars habilitados en el SDK, `--enable-feature=exemplar-storage`
en Prometheus, y la datasource de Grafana configurada con el enlace. Es
exactamente la respuesta correcta al problema de cardinalidad del módulo 07:
obtienes el detalle por petición sin pagarlo en series temporales.
</details>

**10. Tienes RED derivado de métricas directas y RED derivado de spans
(`spanmetrics`). No coinciden. ¿Quién miente?**

<details><summary>Guía</summary>

Ninguno de los dos necesariamente. Las métricas directas cuentan **todas** las
peticiones; las derivadas de spans cuentan solo las **muestreadas**, y si el
muestreo no es uniforme —tail sampling que conserva todos los errores— la tasa de
error derivada de spans está sesgada al alza. También hay diferencias por dónde
se instrumenta (middleware HTTP vs handler) y por spans que no se cierran. La
respuesta senior: para SLOs usa métricas directas, no derivadas de spans, porque
la representatividad importa más que el detalle.
</details>
