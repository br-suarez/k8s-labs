# Causa raíz — Módulo 07

> Solo después de haber hecho los cálculos.

## 1. La aritmética

Primero, cuántas series produce **un** histograma. `prometheus.DefBuckets` del
cliente Go define 11 buckets explícitos:

```
.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10
```

Prometheus añade `+Inf` automáticamente, así que son **12 series `_bucket`**, más
`_sum` y `_count`:

```
series por combinación de etiquetas = 12 + 2 = 14
```

Antes del commit, `pulse_probe_duration_seconds`:

```
result: {success, failure}   = 2 valores
series = 2 × 14              = 28 series
```

Veintiocho series. Nada.

Después de añadir `url`:

```
url:    41.283 valores
result: 2 valores
series = 41.283 × 2 × 14 = 1.155.924 series
```

**Más de un millón de series** de una sola métrica. Prometheus consume del orden
de 1–3 KB de memoria por serie activa entre índice y chunk head, así que solo esa
métrica pide entre 1 y 3 GB, sin contar nada más del cluster.

## 2. Por qué 6Gi no lo arregló

La memoria de Prometheus escala con el **número de series activas**, no con el
volumen de muestras. Cada serie nueva añade una entrada al índice invertido y un
chunk en el bloque head, que vive en memoria durante dos horas antes de
compactarse a disco.

Con 2Gi moría en ~20 minutos. Con 6Gi murió en ~40. La ingesta seguía creando
series a la misma velocidad; solo se movió el momento del choque.

Con 32Gi habría aguantado más y luego habría muerto igual — y además cada
reinicio sería más lento, porque al arrancar hay que reproducir el WAL, que ahora
es enorme. **En algún punto el tiempo de replay del WAL supera el tiempo entre
OOMs y ya no arranca nunca.** Ese es el estado terminal de una explosión de
cardinalidad y es del que cuesta salir.

## 3. Por qué la regla de grabación empeoró las cosas

```promql
sum by (le, url, result, region, check_id) (rate(...))
```

Una regla de grabación **materializa** su resultado como series nuevas y
persistentes. La cardinalidad de la salida es el producto de las etiquetas del
`by`:

```
le (12) × url (41.283) × result (2) × region (4) × check_id (41.283)
```

`url` y `check_id` están correlacionados uno a uno, así que en la práctica no se
multiplican entre sí, pero aun así:

```
12 × 41.283 × 2 × 4 = 3.963.168 series adicionales
```

Escritas cada intervalo de evaluación, para siempre.

**La lección sobre reglas de grabación:** aceleran una consulta *reduciendo*
dimensiones. Una regla que conserva todas las etiquetas del original no
precalcula nada útil — duplica el problema y lo hace permanente. Si tu `by`
contiene una etiqueta de alta cardinalidad, la regla está mal.

## 4. Mitigación, en orden

**Primero: que arranque.** No puedes diagnosticar lo que no corre.

```bash
# 1. Parar la ingesta del culpable — quitar el ServiceMonitor o
#    añadir un metricRelabeling que descarte la métrica
kubectl delete servicemonitor pulse-worker -n monitoring

# 2. Si sigue sin arrancar, el bloque head en disco ya es demasiado grande.
#    Arrancar sin él, aceptando perder las últimas 2h de datos:
#    --storage.tsdb.head-chunks-write-queue-size, o en el peor caso
#    borrar el WAL. Es destructivo: documenta lo que pierdes.
```

**Segundo: recuperar las alertas.** Llevas dos días ciego. Alertmanager no
depende de Prometheus para notificar, pero sí para recibir. Restablecer el
alerting va antes que recuperar los paneles.

**Tercero: revertir el commit.** Solo entonces, con calma.

## 5. El arreglo, conservando la necesidad legítima

El equipo quería investigar latencia por endpoint. Es razonable. Lo que no es
razonable es hacerlo con una etiqueta de Prometheus.

| Enfoque | Cómo | Coste |
|---|---|---|
| **Exemplars** | El histograma agregado conserva un ejemplo por bucket con el trace ID | Casi cero. **Es la respuesta correcta** |
| Agrupar por dimensión acotada | `tenant` (340) o `check_tier` (3) en vez de `url` | Bajo, pero pierde el detalle por endpoint |
| Trazas | La latencia por endpoint vive en trazas, no en métricas | Módulo 08 |
| Logs | Consulta agregada sobre logs estructurados | Alta latencia de consulta |

La respuesta correcta es **exemplars**, y es exactamente el puente al módulo 08:
la métrica queda agregada y barata, y cada bucket lleva un enlace a una traza
real que muestra ese endpoint concreto. Obtienes el detalle sin pagar la
cardinalidad.

La regla general: **una etiqueta de Prometheus debe tener un conjunto de valores
acotado y conocido de antemano.** Si no puedes escribir el número máximo de
valores distintos en una servilleta, no es una etiqueta — es un campo de traza o
de log.

Prohibido como etiqueta: URL, user ID, request ID, email, IP, timestamp, nombre
de pod en workloads efímeros, cualquier cosa derivada de entrada del usuario.

## 6. El control que faltaba

Tres capas, de más barata a más cara:

**a) Un límite en el propio Prometheus.** Debió existir desde el día uno:

```yaml
spec:
  enforcedSampleLimit: 50000
  enforcedLabelLimit: 30
  enforcedLabelValueLengthLimit: 2048
```

Con esto, el scrape del objetivo problemático falla y Prometheus sigue vivo.
Pierdes una métrica en vez de todo el sistema de monitorización — que es
exactamente el intercambio que quieres.

**b) Una alerta sobre la propia cardinalidad:**

```promql
# Series activas, con umbral
prometheus_tsdb_head_series > 1000000

# Y crecimiento, que avisa antes
deriv(prometheus_tsdb_head_series[1h]) > 1000
```

La segunda es la buena: detecta la tendencia horas antes del OOM.

**c) Una comprobación en CI.** Un test que ejecute las reglas de grabación
propuestas contra datos de muestra y falle si la cardinalidad de salida supera un
umbral. `promtool test rules` es el punto de partida.

## Lo que se pregunta en entrevista sobre este caso

No es "¿qué es la cardinalidad?". Es: **tu sistema de monitorización estuvo caído
dos días y nadie lo notó. ¿Cómo lo evitas?**

La respuesta: monitorizar Prometheus con algo que no sea Prometheus. Un
dead-man's switch — una alerta que dispara **siempre** y cuya *ausencia* es la
señal — enrutada a un canal distinto. Si el latido deja de llegar, tu
observabilidad está caída, y eso lo sabes en minutos y no en días.
