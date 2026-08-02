# Causa raíz — Módulo 08

> Solo después de haber escrito tu hipótesis y las métricas que la comprobarían.

## 1. Las métricas que lo dicen

```promql
# El escalón está aquí
rate(otelcol_processor_refused_spans[1m])          # memory_limiter rechazando
rate(otelcol_exporter_enqueue_failed_spans[1m])    # cola de envío llena
rate(otelcol_exporter_send_failed_spans[1m])       # fallos hacia Tempo
otelcol_exporter_queue_size / otelcol_exporter_queue_capacity
```

A las 14:20, `otelcol_processor_refused_spans` pasa de 0 a miles por segundo, y
`queue_size` se pega al 100% de capacidad.

**El Collector estaba haciendo exactamente lo que le pediste**: proteger su
propia memoria descartando datos. Lo que no hizo fue avisar a nadie.

## 2. Por qué justo durante el incidente

Aquí está la parte contraintuitiva. Durante el incidente:

| Factor | Efecto sobre el volumen de spans |
|---|---|
| Latencia alta → más peticiones concurrentes en vuelo | Más spans simultáneos |
| Errores → `RecordError` con eventos de excepción y stack | Spans **mucho más grandes** |
| Reintentos del worker | Multiplica los spans por sondeo |
| Los sondeos lentos mantienen spans abiertos más tiempo | Más spans vivos a la vez |

El volumen de telemetría no crece un poco durante un incidente: crece de forma no
lineal, y el tamaño medio del span crece con él. Un Collector dimensionado para
el estado sano no está dimensionado para el estado que te importa.

Ese es el fallo estructural: **la telemetría se dimensiona con el caso bueno y se
necesita en el caso malo.**

## 3. El error de orden

```yaml
processors: [batch, memory_limiter]     # ← mal
```

`batch` acumula hasta 8192 spans en memoria antes de enviarlos. `memory_limiter`
comprueba el uso y rechaza cuando se pasa.

Con este orden, `batch` acumula **primero** —consumiendo la memoria— y
`memory_limiter` actúa después, cuando el daño ya está hecho. El limitador
protege de lo que viene detrás de él, no de lo que tiene delante.

```yaml
processors: [memory_limiter, batch]     # ← correcto
```

`memory_limiter` debe ser **el primer processor del pipeline**, siempre. Así
rechaza en la entrada, antes de que nada acumule. Está documentado y es de los
errores de configuración más comunes que existen.

Detalle importante: con el orden correcto el Collector aplica *backpressure* al
SDK de la aplicación, que a su vez tiene su propia cola y su propio
comportamiento al llenarse. La pérdida se mueve, no desaparece — pero al menos
se hace visible en las métricas del SDK.

## 4. ¿Era suficiente `queue_size: 1000`?

`queue_size` se cuenta en **batches**, no en spans. Con `send_batch_size: 8192`:

```
1000 batches × 8192 spans = 8.192.000 spans de capacidad teórica
```

Suena enorme. Pero la cola solo importa si Tempo está lento; si el problema es
`memory_limiter` rechazando en la entrada, los spans nunca llegan a la cola.

Estimación del volumen real durante el incidente, con los números que tienes:

```
~300 checks × reintentos ≈ 3 spans/sondeo
sondeos cada 5s durante 30 min = 360 ciclos
300 × 3 × 360 ≈ 324.000 spans

Con atributos de error, ~2 KB/span → ~650 MB de datos
Límite de memoria del Collector: 512 Mi
```

**No cabía.** El problema no era la cola: era que el Collector tenía menos memoria
que el pico de telemetría que el incidente generaba.

## 5. El arreglo

```yaml
processors:
  # PRIMERO, siempre
  memory_limiter:
    check_interval: 1s
    limit_percentage: 75          # relativo al límite del contenedor
    spike_limit_percentage: 15

  # Muestreo por cola: quedarse con lo que importa en vez de perder al azar
  tail_sampling:
    decision_wait: 10s
    num_traces: 20000
    policies:
      - name: errors
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow
        type: latency
        latency: {threshold_ms: 1000}
      - name: baseline
        type: probabilistic
        probabilistic: {sampling_percentage: 5}

  batch:
    timeout: 5s
    send_batch_size: 1024         # lotes más pequeños, picos de memoria menores
    send_batch_max_size: 2048

exporters:
  otlp/tempo:
    endpoint: tempo.monitoring.svc:4317
    tls: {insecure: true}
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 5000
      storage: file_storage        # ← sobrevive a reinicios
    retry_on_failure:
      enabled: true
      max_elapsed_time: 300s

extensions:
  file_storage:
    directory: /var/lib/otelcol/queue

service:
  extensions: [file_storage]
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [memory_limiter, tail_sampling, batch]
      exporters:  [otlp/tempo]
```

Cambios y por qué:

| Cambio | Razón |
|---|---|
| `memory_limiter` primero | Rechaza en la entrada, no después de acumular |
| `limit_percentage` en vez de `limit_mib` | Se ajusta solo si cambias el límite del pod |
| `tail_sampling` | La clave: descarta lo aburrido, **conserva errores y lentitud** |
| `send_batch_size` de 8192 → 1024 | Picos de memoria mucho menores |
| `storage: file_storage` | La cola sobrevive a un reinicio del Collector |
| `queue_size` 1000 → 5000 | Más margen, ahora que los lotes son pequeños |

El cambio que de verdad resuelve el problema es **tail sampling**. Con head
sampling al 5% habrías conservado el 5% de las trazas del incidente elegidas al
azar. Con tail sampling conservas el **100% de las trazas con error o lentas** y
solo el 5% de las normales: menos volumen total y toda la información que
importa.

Y es la respuesta a la pregunta 4 del diagnóstico: "quiero todas las trazas de
error a un muestreo global del 1%" solo es posible con tail sampling, porque la
decisión requiere haber visto la traza completa.

## 6. Cómo enterarte mientras pasa

Alertas sobre el propio Collector, en el mismo Prometheus del módulo 07:

```yaml
- alert: CollectorDroppingSpans
  expr: rate(otelcol_processor_refused_spans[5m]) > 0
  for: 2m
  annotations:
    summary: "El Collector está descartando telemetría — hay un hueco en los datos"

- alert: CollectorQueueNearFull
  expr: otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 0.8
  for: 5m

- alert: TelemetryVolumeCollapsed
  expr: |
    rate(otelcol_receiver_accepted_spans[10m])
      < 0.5 * rate(otelcol_receiver_accepted_spans[10m] offset 1h)
  for: 10m
  annotations:
    summary: "El volumen de spans cayó a la mitad — ¿silencio real o pérdida?"
```

La tercera es la más importante y la que casi nadie tiene. **La ausencia de datos
parece calma.** Sin una alerta sobre la caída del volumen, un pipeline de
telemetría muerto y un sistema perfectamente tranquilo producen exactamente el
mismo panel.

Es el mismo razonamiento del dead-man's switch del módulo 07, aplicado a las
trazas: hay que alertar sobre el silencio, no solo sobre el ruido.
