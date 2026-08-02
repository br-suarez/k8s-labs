# Lab 08b.01 — Ronda 1: tres fallos

**CORE · 60 min**

## Antes de empezar

- [ ] `./platform/scripts/verify.sh` pasa entero
- [ ] Tienes un cronómetro
- [ ] Tienes abierto un archivo para la bitácora, **no** vas a confiar en la
      memoria
- [ ] **No** has leído `scripts/gameday-1.sh`

## El ejercicio

```bash
./scripts/gameday-1.sh inject 3
```

Tres fallos simultáneos. Pueden interactuar entre sí — uno puede enmascarar a
otro, y eso es deliberado, porque en producción también pasa.

## La bitácora

Una fila por comando. Rellénala **mientras**, no después.

| Hora | Comando | Qué esperaba ver | Qué vi | Qué descarta |
|------|---------|------------------|--------|---------------|
| | | | | |

La columna "qué descarta" es la que convierte tantear en diagnosticar. Un
comando que no descarta nada no deberías haberlo ejecutado.

## Las reglas

**1. Mitiga primero, entiende después.**
Si puedes restaurar el servicio sin saber la causa, hazlo y anota la hora. El
entendimiento viene luego. Este es el hábito que más cuesta a los ingenieros
técnicamente fuertes, porque el instinto es entender antes de tocar.

**2. Hipótesis antes de comando.**
Antes de ejecutar algo, escribe qué esperas ver si tu hipótesis es cierta. Si no
sabes qué esperas, estás tanteando.

**3. Una cosa cada vez.**
Cambiar tres cosas y ver que se arregla no te dice cuál era.

**4. Nada de `--force`, nada de `delete` sin pensar.**
Aplica todo lo del módulo 06. Un `--force` sobre almacenamiento compartido puede
convertir un incidente en pérdida de datos.

## Los tiempos que hay que registrar

| Hito | Hora | Δ desde inyección |
|---|---|---|
| Inyección | | 00:00 |
| Primer síntoma detectado | | |
| Fallo 1 diagnosticado | | |
| Fallo 1 mitigado | | |
| Fallo 2 diagnosticado | | |
| Fallo 2 mitigado | | |
| Fallo 3 diagnosticado | | |
| Fallo 3 mitigado | | |
| `verify.sh` en verde | | |

**Mediana de tiempo hasta diagnóstico** — es el número que vas a comparar con el
del módulo 16 dentro de catorce semanas.

## Por dónde empezar

No hay una respuesta correcta, pero hay una mala: empezar por `kubectl logs` de
un pod al azar.

Sugerencia — de arriba abajo, del síntoma del usuario hacia dentro:

```bash
# 1. ¿Qué ve un usuario?
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/api/checks

# 2. ¿Qué dice el harness? Ya sabe comprobar nueve cosas
./platform/scripts/verify.sh

# 3. ¿Qué dicen los SLOs y las alertas del módulo 07?
# 4. ¿Y las trazas del módulo 08? ¿Dónde se corta el camino?
# 5. Solo entonces, hacia los objetos concretos
```

El paso 2 existe porque lo construiste tú. Si el harness no detecta el fallo,
esa es una conclusión del ejercicio y una tarea de remediación.

## Al terminar

**No ejecutes `restore` todavía.** Primero:

1. Escribe tu diagnóstico de los tres fallos.
2. `./scripts/gameday-1.sh status` para ver cuáles eran de verdad.
3. Lee ahora sí el script y compara con lo que dedujiste.

Anota los que diagnosticaste mal. Son más valiosos que los que acertaste.

```bash
./scripts/gameday-1.sh restore
./platform/scripts/verify.sh
```
