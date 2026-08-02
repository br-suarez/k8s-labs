# Break-fix — Módulo 08

## El escenario

Ayer, 14:20–14:50, Pulse tuvo un incidente: latencia p99 de 8 segundos, cientos
de sondeos perdidos, clientes quejándose.

Hoy toca el postmortem. Abres Grafana, seleccionas la ventana del incidente y
buscas las trazas.

**No hay ninguna.**

```
Tempo query: {resource.service.name="pulse-api"}
Time range:  2026-08-01 14:15 → 14:55
Results:     0 traces
```

Mueves la ventana a 13:00–14:00: 4.200 trazas. A 15:00–16:00: 3.900 trazas.
Justo la media hora que necesitas está vacía.

Nadie tocó nada. El Collector no se reinició — 11 días de uptime.

## La configuración del Collector

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 5s
    send_batch_size: 8192

  memory_limiter:
    check_interval: 1s
    limit_mib: 400
    spike_limit_mib: 100

exporters:
  otlp/tempo:
    endpoint: tempo.monitoring.svc:4317
    tls:
      insecure: true
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 1000
    retry_on_failure:
      enabled: true
      max_elapsed_time: 300s

service:
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [batch, memory_limiter]
      exporters:  [otlp/tempo]
```

Recursos del Collector:

```yaml
resources:
  limits:
    memory: 512Mi
  requests:
    memory: 256Mi
```

## Lo que sí tienes

Las métricas del módulo 07 de la ventana del incidente están completas. Y el
Collector expone sus propias métricas en `:8888`, que alguien tuvo el buen
criterio de scrapear.

## Tu trabajo

1. **No adivines.** ¿Qué métricas del propio Collector consultas, y qué esperas
   ver en cada una si tu hipótesis es correcta?
2. Explica por qué se perdieron las trazas exactamente durante el incidente y no
   antes ni después.
3. Hay un error de **orden** en el pipeline que empeora el problema.
   Encuéntralo y explica el mecanismo.
4. Calcula si `queue_size: 1000` era suficiente. Necesitas estimar el volumen de
   spans durante el incidente — hazlo con los números que tengas.
5. Arréglalo. Debe seguir funcionando dentro del presupuesto de memoria de un
   cluster pequeño.
6. ¿Cómo te enteras la próxima vez **mientras** pasa, en vez de al día siguiente
   en el postmortem?

## Pistas escalonadas

<details><summary>Pista 1</summary>

El Collector se instrumenta a sí mismo. Empieza por
`otelcol_receiver_refused_spans`, `otelcol_processor_dropped_spans` y
`otelcol_exporter_send_failed_spans`. Uno de esos tres tiene un escalón enorme a
las 14:20.
</details>

<details><summary>Pista 2</summary>

Durante el incidente, ¿qué le pasó al **volumen** de telemetría? Un sistema con
latencia alta y errores no genera menos spans: genera más, y más grandes, porque
los spans con error llevan atributos y eventos de excepción.
</details>

<details><summary>Pista 3 — para el punto 3</summary>

Lee el orden: `processors: [batch, memory_limiter]`. Piensa qué hace `batch`
—acumular spans en memoria— y en qué momento quieres que actúe el limitador de
memoria. ¿Antes o después de que algo haya acumulado 8192 spans?
</details>

<details><summary>Pista 4 — para el punto 5</summary>

`sending_queue` es una cola **en memoria**. Cuando el Collector se reinicia o la
cola se llena, los datos desaparecen. Existe una extensión que la respalda en
disco.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Es la propiedad más incómoda de la observabilidad: **el sistema falla justo
cuando más lo necesitas**, porque el incidente es precisamente lo que genera la
carga que lo tumba. Y falla en silencio — no hay error en la aplicación, no hay
alerta, solo un hueco en los datos que descubres al día siguiente.
