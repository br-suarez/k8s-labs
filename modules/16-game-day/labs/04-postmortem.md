# Lab 16.04 — Postmortem y remediación

**CORE · 50 min.** En la misma sesión que las rondas.

## El entregable

`modules/16-game-day/POSTMORTEM-2.md`, en inglés, con la misma estructura del
módulo 08c más dos secciones nuevas.

### 1–6. Como en el Game Day I

Resumen, cronología (con las hipótesis fallidas), causa raíz por fallo, factores
contribuyentes, qué salió bien, y acciones con dueño y criterio de terminado.

### 7. Interacciones entre fallos

Nueva. Con cinco fallos simultáneos:

- ¿Cuál enmascaraba a cuál?
- ¿Hubo alguno que solo pudiste ver después de arreglar otro?
- ¿Arreglar uno empeoró otro temporalmente?
- ¿En qué orden habría sido óptimo abordarlos, sabiendo lo que sabes ahora?

Esta sección es lo que distingue un incidente real de un ejercicio: en producción
los fallos rara vez vienen solos.

### 8. La comparación

| | Game Day I | Game Day II |
|---|---|---|
| Fecha | semana 15 | semana 28 |
| Capas | 7 | 13 |
| Fallos | 3 | 3 y 5 |
| Mediana hasta diagnóstico | | |
| Hipótesis fallidas por fallo | | |
| ¿Lo habría resuelto de guardia? | | |

Y en prosa, tres párrafos:

1. **Qué haces distinto ahora.** No qué sabes — qué *haces*. Qué comando ejecutas
   primero y por qué cambió.
2. **Qué sigue costándote.** Sé específico. "Debugging" no es una respuesta;
   "correlacionar entre capas cuando la observabilidad está degradada" sí.
3. **Qué le dirías a quien empieza este track.**

## La parte que no es escribir

**Implementa al menos dos acciones antes de cerrar el módulo.**

Al menos una tiene que ser una comprobación nueva en `verify.sh`. El criterio es
el mismo del 08c: si el harness no detectó algo que tú acabaste encontrando,
debería poder la próxima vez.

Verifica que funciona:

```bash
./scripts/gameday-2.sh inject 1     # repite hasta que salga el que quieres
./platform/scripts/verify.sh        # debe fallar señalándolo
./scripts/gameday-2.sh restore
```

## La autoevaluación final

Vuelve al `TRACKER.md` y rellena la columna Nivel de los diecinueve módulos, con
el criterio de siempre: **el más bajo de los cuatro criterios de salida, no el
promedio.**

| Pregunta | Respuesta |
|---|---|
| ¿Cuántos módulos en 4 o más? | |
| ¿Cuántos en 5? | |
| ¿Cuál es el más bajo? ¿Por qué? | |
| ¿Cuál subestimaste al empezar? | |
| ¿Cuál sobreestimaste? | |

El objetivo del plan era 4 en todos y 5 en al menos seis. Si no llegas, eso no es
un fracaso del plan: es la lista de lo que repasar en los próximos meses, y es
más útil que un certificado.

## Expected outcome

`POSTMORTEM-2.md` completo con las dos secciones nuevas, dos acciones
implementadas y verificadas, y el `TRACKER.md` cerrado con la autoevaluación de
los diecinueve módulos.
