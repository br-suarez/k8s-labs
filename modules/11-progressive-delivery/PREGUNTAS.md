# Preguntas de entrevista — Módulo 11

## El análisis

**1. Tu canary tiene el 10% del tráfico y falla el 100% de sus peticiones. La
consulta mide la tasa de error global. ¿Qué valor sale y qué implica?**

<details><summary>Guía</summary>

`0.10 × 1.0 + 0.90 × 0 = 0.10`. Es decir, **el valor medido es el peso del
canary**. Con un umbral del 15% pasa; con el canary al 1% pasaría cualquier
umbral razonable. Implicación: una consulta no acotada al canary es menos
sensible cuanto menor es el peso — falla exactamente en el paso donde más
protección necesitas. Se acota filtrando por
`rollouts_pod_template_hash`, y eso exige propagar esa etiqueta desde el pod
hasta la métrica en el ServiceMonitor.
</details>

**2. ¿Por qué la pausa antes de medir no puede ser menor que la ventana de la
métrica?**

<details><summary>Guía</summary>

Porque `rate(...[5m])` promedia cinco minutos. Si mides 30 segundos después de
enviar tráfico al canary, la ventana está llena de datos anteriores a que el
canary existiera, y el resultado está diluido hacia el estado sano. El análisis
promociona sobre datos que todavía no reflejan la realidad. Regla:
`initialDelay ≥ ventana del rate`, y la pausa total ≥ tiempo hasta que la métrica
refleja el cambio.
</details>

**3. `successCondition: result[0] < 1.0` sobre una tasa de error. ¿Qué está mal?**

<details><summary>Guía</summary>

Una tasa de error es una proporción entre 0 y 1, así que la condición solo es
falsa si absolutamente todo falla. No es un umbral, es un adorno que da
sensación de protección. El número debe derivarse del SLO: con un objetivo de
99.9%, un canary al 5% de error quema presupuesto a 50x y debe rechazarse.
</details>

**4. El canary aún no ha recibido tráfico y la consulta divide por cero. ¿Qué
devuelve y qué hace el análisis?**

<details><summary>Guía</summary>

PromQL devuelve `NaN` o serie vacía. Según la configuración, un resultado vacío
puede tratarse como no concluyente en vez de como fallo, con lo que el paso pasa
sin haber medido nada. Se mitiga con `clamp_min` en el denominador, exigiendo un
volumen mínimo de peticiones antes de evaluar, y siendo explícito sobre qué hacer
ante datos ausentes. La postura correcta: **ausencia de datos no es éxito.**
</details>

## Mecánica

**5. Reparto de tráfico por réplicas vs por el proveedor de red. ¿Diferencia?**

<details><summary>Guía</summary>

Por réplicas, el peso es aproximado y granular: con 3 réplicas no puedes hacer un
10%, lo más fino es un 33%. Por proveedor —Gateway API, un mesh, un ingress con
soporte— el peso es exacto e independiente del número de pods. Además el reparto
por réplicas te obliga a escalar para afinar, lo que cambia la capacidad mientras
mides. Para canarios finos hace falta el segundo.
</details>

**6. Se aborta un rollout. ¿Qué pasa con las peticiones en vuelo hacia el canary?**

<details><summary>Guía</summary>

Se retira el peso y los pods del canary se terminan. Las peticiones en vuelo
dependen de lo mismo del módulo 04: `preStop`, propagación del endpoint, y
manejo de `SIGTERM`. Un abort con esas tres cosas mal configuradas convierte un
rollback —que debería ser invisible— en un segundo incidente. Es la razón de que
el módulo 04 lab 06 exista antes que este.
</details>

**7. Canary vs blue/green. Un caso donde blue/green gana claramente.**

<details><summary>Guía</summary>

Cuando las dos versiones no pueden coexistir: una migración de esquema
incompatible, un cambio de formato de mensajes en una cola, o cualquier estado
compartido que las dos versiones interpreten distinto. El canary asume que
convivir es seguro. Blue/green también gana cuando necesitas validar contra el
entorno real antes de exponer a nadie, y cuando el rollback debe ser instantáneo
—cambiar un puntero— en vez de un rollout progresivo.
</details>

## Confianza

**8. Tu canary lleva seis semanas y ha rechazado tres releases. ¿Qué te dice eso?**

<details><summary>Guía</summary>

Menos de lo que parece. Que rechace demuestra que puede rechazar **esos** fallos.
No demuestra sensibilidad: un análisis mal acotado detecta un servicio que no
arranca —fallo total, visible con cualquier consulta— y no detecta uno que falla
el 100% de una ruta concreta. La única evidencia real es una prueba que despliega
deliberadamente un canary roto y exige el rechazo, ejecutada en CI. Es el mismo
principio que un backup que nunca se ha restaurado.
</details>

**9. Un canary promovió un release roto. Tres candidatos: métrica, umbral,
tiempo. ¿Cómo discriminas?**

<details><summary>Guía</summary>

Reconstruye los valores que midió el análisis y compáralos con lo que la métrica
valía **realmente** en el canary durante esa ventana. Si el medido es mucho menor
que el real, el problema es la métrica —mal acotada—. Si coinciden y aun así
pasó, es el umbral. Si el medido está diluido hacia el estado anterior, es el
tiempo. La progresión de valores a lo largo de los pasos suele delatar cuál: si
crece proporcionalmente al peso del canary, la métrica no está acotada.
</details>

**10. ¿Qué NO detecta un canary, por bien configurado que esté?**

<details><summary>Guía</summary>

Fallos que necesitan tiempo o volumen: fugas de memoria, agotamiento de
conexiones, colas que crecen lentamente, corrupción de datos que solo se nota
después. También cualquier cosa que dependa de que el 100% del tráfico esté en la
versión nueva, y regresiones en rutas de bajo tráfico que el canary
estadísticamente no toca. Por eso el canary no sustituye a las alertas de burn
rate del módulo 07: cubren ventanas temporales distintas.
</details>
