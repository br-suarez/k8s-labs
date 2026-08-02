# Lab 08b.02 — Postmortem y remediación

**CORE · 40 min.** En la misma sesión que la ronda 1, sin excepción.

## Contexto

Un postmortem escrito tres días después es ficción: te acuerdas de la versión
ordenada, no de la real, y precisamente los callejones sin salida son lo que
tiene valor.

## El entregable

`modules/08b-game-day-i/POSTMORTEM-1.md`, en inglés, con esta estructura.

### 1. Resumen

Tres frases. Qué se rompió, cuánto duró, a quién habría afectado en producción.

### 2. Cronología

De la bitácora, sin adornar. Incluye las hipótesis equivocadas — **son la parte
útil**.

```
14:02  Injection. First symptom: 503 from the gateway.
14:04  Checked pod status. All Running, 0 restarts. Hypothesis: routing.
14:07  Checked HTTPRoute status. Accepted=True. Hypothesis wrong.
14:09  Checked endpoints. Empty. → Service selector.
...
```

### 3. Causa raíz

Para cada fallo: qué era, qué comando lo confirmó, y **cuánto tardaste en
llegar**.

### 4. Factores contribuyentes

Lo que hizo el diagnóstico más lento de lo necesario. Suele haber más aquí que
en la causa raíz:

- ¿Faltaba una alerta que lo habría señalado?
- ¿Un fallo enmascaraba a otro?
- ¿Un panel decía algo engañoso?
- ¿Perdiste tiempo en un camino que un comando barato habría descartado antes?

### 5. Qué salió bien

No es relleno. Si algo funcionó —el harness detectó dos de tres, la traza señaló
el servicio correcto— eso hay que preservarlo, y solo lo sabes si lo escribes.

### 6. Acciones

Concretas, con dueño y criterio de terminado. Nada de "mejorar la
monitorización".

| Acción | Por qué | Terminado cuando |
|---|---|---|
| Añadir grupo `endpoints` a `verify.sh` que falle si un Service tiene 0 endpoints | El fallo 2 tardó 11 min y el harness no lo veía | El grupo detecta el fallo inyectado |

## La parte que no es escribir

**Implementa al menos una acción antes de cerrar el módulo.**

Casi siempre es una comprobación nueva en `platform/scripts/verify.sh`. El
criterio: si el harness no detectó un fallo que tú sí acabaste encontrando,
debería poder hacerlo la próxima vez.

Después, vuelve a inyectar ese mismo fallo y comprueba que ahora el harness lo
caza:

```bash
./scripts/gameday-1.sh inject 1     # repite hasta que salga el que quieres
./platform/scripts/verify.sh        # debería fallar señalándolo
./scripts/gameday-1.sh restore
```

**Un Game Day que no cambia el sistema después fue entretenimiento.**

## Autoevaluación

| Pregunta | Respuesta |
|---|---|
| Mediana de tiempo hasta diagnóstico | |
| ¿Mitigué antes de entender, o al revés? | |
| ¿Cuántas hipótesis fallé antes de acertar? | |
| ¿Qué comando fue el que más descartó por minuto invertido? | |
| ¿Habría podido hacerlo estando de guardia, a las 4am? | |

Esa última fila es el criterio de salida real del módulo, y es el que vas a
volver a responder en el módulo 16.

## Nota

Guarda este postmortem. En la semana 26 vas a escribir otro sobre un sistema
mucho más complejo, y ponerlos uno al lado del otro es la mejor evidencia de
progreso que va a contener este repositorio — mejor que cualquier autoevaluación
del `TRACKER.md`.
