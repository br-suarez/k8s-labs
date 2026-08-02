# Preguntas de entrevista — Módulo 07

## PromQL

**1. `rate()` vs `irate()` vs `increase()`. ¿Cuál para una alerta?**

<details><summary>Guía</summary>

`rate()`: media por segundo sobre toda la ventana, suaviza picos — es lo que
quieres para alertar. `irate()`: usa solo los dos últimos puntos, muy reactivo y
muy ruidoso; sirve para gráficas de alta resolución, nunca para alertas, porque
dispara con un solo pico. `increase()` es `rate() × segundos de la ventana`, útil
para "cuántos errores en la última hora" pero sujeto a extrapolación en los
bordes. Todos requieren counters, y todos manejan los reinicios del counter
automáticamente.
</details>

**2. Un panel de p99 tarda 8 segundos. Tres causas y cómo las distingues.**

<details><summary>Guía</summary>

(a) Alta cardinalidad: la consulta toca demasiadas series —
`prometheus_engine_query_duration_seconds` y el número de series que devuelve.
(b) Ventana muy larga sin regla de grabación: calcular `histogram_quantile` sobre
30 días de datos crudos en cada refresco. (c) Un `by` con demasiadas dimensiones
que fuerza agregación sobre millones de puntos. Se distinguen mirando cuántas
series devuelve la consulta y probando la misma consulta sobre 1 h en lugar de
30 d.
</details>

**3. `histogram_quantile(0.99, ...)` con buckets `[0.1, 0.5, 1, 5]` y un p99 real
de 2,3 s. ¿Qué devuelve?**

<details><summary>Guía</summary>

Un valor interpolado linealmente dentro del bucket `(1, 5]`, que no será 2,3 sino
lo que salga de asumir distribución uniforme dentro de ese bucket — típicamente
bastante desviado. Los histogramas de Prometheus dan precisión limitada por los
límites de bucket, y un p99 que cae en un bucket ancho es esencialmente una
conjetura. Corolario: los buckets hay que elegirlos alrededor del SLO. Si tu SLO
es 300 ms, necesitas buckets densos alrededor de 300 ms, no la escala por
defecto.
</details>

## Cardinalidad

**4. ¿Qué es la cardinalidad y cómo se calcula la de una métrica?**

<details><summary>Guía</summary>

El número de series temporales únicas, que es el **producto** de los valores
distintos de cada etiqueta — no la suma. Para un histograma hay que multiplicar
además por el número de buckets más 2 (`_sum` y `_count`). Regla práctica: si no
puedes escribir el número máximo de valores distintos de una etiqueta antes de
añadirla, no es una etiqueta.
</details>

**5. ¿Qué nunca debe ser una etiqueta de Prometheus, y dónde va esa información?**

<details><summary>Guía</summary>

URL, user ID, request ID, email, IP, timestamp, nombre de pod en workloads
efímeros — cualquier cosa no acotada o derivada de entrada del usuario. Esa
información pertenece a trazas o a logs estructurados. El puente entre ambos
mundos son los **exemplars**: la métrica queda agregada y barata, y cada bucket
conserva un enlace a una traza que sí tiene el detalle.
</details>

**6. Prometheus está en OOMKill. Le subes la memoria al triple y sigue igual.
¿Por qué?**

<details><summary>Guía</summary>

Porque la memoria escala con series activas, no con muestras, y la ingesta sigue
creando series al mismo ritmo. Subir el límite mueve el momento del choque.
Peor: cada reinicio tarda más porque hay que reproducir un WAL más grande, y
existe un punto en el que el replay tarda más que el intervalo entre OOMs y ya no
arranca nunca. Hay que parar la ingesta del culpable, no darle más memoria.
</details>

## SLIs y SLOs

**7. Pulse monitoriza endpoints ajenos. ¿Por qué "porcentaje de sondeos
exitosos" es un mal SLI?**

<details><summary>Guía</summary>

Porque mide la salud de **los sistemas de otros**, no la tuya. Si un cliente
apunta Pulse a un endpoint caído, tu SLI se degrada y te paginan por algo que
funciona exactamente como debe. El SLI correcto mide si Pulse hizo su trabajo:
¿ejecutó el sondeo dentro de su intervalo programado?, ¿registró el resultado?,
¿respondió la API? Distinguir "mi sistema falla" de "el sistema observado falla"
es el problema central de cualquier herramienta de monitorización.
</details>

**8. ¿Por qué burn rate multiventana en vez de un umbral simple?**

<details><summary>Guía</summary>

Un umbral simple sobre la tasa de error paginará por un pico irrelevante o
tardará horas en detectar una degradación lenta que igualmente consume el
presupuesto. El burn rate mide a qué velocidad se consume el error budget. Dos
ventanas: la larga confirma que es sostenido, la corta permite que la alerta se
resuelva rápido cuando el problema termina. Sin la ventana corta, la alerta sigue
disparada mucho después de que todo se haya arreglado, y la gente aprende a
ignorarla.
</details>

**9. ¿Qué es un dead-man's switch y por qué lo necesitas?**

<details><summary>Guía</summary>

Una alerta configurada para disparar **siempre**, enrutada a un sistema externo
que espera recibirla periódicamente. Su *ausencia* es la señal. Sin él, un
Prometheus caído produce exactamente el mismo silencio que un sistema
perfectamente sano — y esa ambigüedad es lo que permite estar dos días sin
alertas sin saberlo. Es el argumento completo de por qué tu observabilidad
necesita observabilidad, y debe vivir fuera del sistema que vigila.
</details>

## Reglas de grabación

**10. ¿Cuándo una regla de grabación NO ayuda?**

<details><summary>Guía</summary>

Cuando su `by` conserva todas las etiquetas del original: no precalcula nada,
materializa el mismo conjunto de series de forma permanente y duplica el
problema. Las reglas de grabación aceleran **reduciendo dimensiones**. Si tu `by`
incluye una etiqueta de alta cardinalidad, la regla está mal planteada — y
probablemente esté a punto de tumbarte el Prometheus.
</details>
