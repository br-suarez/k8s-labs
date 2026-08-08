# Lab 16.03 — Ronda 2: cinco fallos, sin red

**CORE · 50 min**

## Contexto

La última vez. Cinco fallos simultáneos sobre las trece capas, y esta vez sin las
ayudas de la ronda 1.

## Reglas adicionales

- **Sin usar `verify.sh` en los primeros 10 minutos.** Diagnostica desde los
  síntomas y desde la observabilidad que construiste, no desde el harness. El
  harness es tuyo y sabe demasiado.
- **Cronometra desde el primer segundo.**
- Objetivo: mediana de tiempo hasta diagnóstico **por debajo de 15 minutos**.

```bash
./scripts/gameday-2.sh inject 5
```

## Por qué sin el harness al principio

En un incidente real no vas a tener una comprobación escrita a medida para el
fallo que estás viviendo. Vas a tener paneles, trazas, logs y `kubectl`. Los
primeros diez minutos entrenan eso.

Después de los diez, úsalo — es tuyo y para eso lo construiste.

## La bitácora

Igual que la ronda 1, más una columna:

| Hora | Comando | Hipótesis | Qué vi | Qué descarta | ¿Enmascaraba otro fallo? |
|------|---------|-----------|--------|---------------|---------------------------|

Con cinco fallos simultáneos, la última columna se llena. Un fallo que hace que
Prometheus vaya lento hace que **todo** parezca roto.

## Preguntas al terminar

1. ¿Cuál diagnosticaste más rápido? ¿Por qué?
2. ¿Cuál más lento? ¿Qué te habría ayudado?
3. ¿Alguno lo diagnosticaste mal y perdiste tiempo?
4. ¿Cuál enmascaraba a otro? ¿Cómo lo descubriste?
5. En los primeros 10 minutos sin el harness, ¿qué echaste de menos? ¿Existe y no
   lo miraste, o no existe?

La pregunta 5 es la que genera acciones de remediación de verdad.

## Los tres números

| Medida | Game Day I (sem. 15) | Ronda 1 | Ronda 2 |
|---|---|---|---|
| Capas del sistema | 7 | 13 | 13 |
| Fallos simultáneos | 3 | 3 | 5 |
| Mediana hasta diagnóstico | | | |
| Hipótesis fallidas | | | |

Esa tabla es la evidencia de progreso más honesta que va a contener este
repositorio. Va al README del módulo.

## Al terminar

```bash
./scripts/gameday-2.sh status     # spoiler, después de escribir tu diagnóstico
./scripts/gameday-2.sh restore
./platform/scripts/verify.sh
```

Y directo al lab 04, en la misma sesión.
