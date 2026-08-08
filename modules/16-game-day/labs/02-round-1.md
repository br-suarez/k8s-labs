# Lab 16.02 — Ronda 1: tres fallos sobre trece capas

**CORE · 60 min**

## Antes de empezar

- [ ] `./platform/scripts/verify.sh` pasa entero
- [ ] Cronómetro listo
- [ ] Bitácora abierta — no vas a confiar en la memoria
- [ ] **No** has leído `scripts/gameday-2.sh`
- [ ] Tienes a mano tu `POSTMORTEM-1.md` del módulo 08c, **sin abrirlo todavía**

## El ejercicio

```bash
./scripts/gameday-2.sh inject 3
```

Diferencia con el Game Day I: **estos fallos interactúan**. Uno puede enmascarar
a otro, y el orden en que los arregles cambia lo que puedes observar.

## La bitácora

| Hora | Comando | Hipótesis | Qué vi | Qué descarta |
|------|---------|-----------|--------|---------------|
| | | | | |

## Las reglas, iguales que en el 08c

1. **Mitiga primero, entiende después.**
2. Hipótesis antes de comando.
3. Una cosa cada vez.
4. Nada de `--force` sin haber descartado almacenamiento en red.

Y una nueva:

5. **Si arreglar A hace que B empeore, párate y anótalo.** Es la interacción, y
   es lo que este Game Day añade sobre el anterior.

## Los tiempos

| Hito | Hora | Δ |
|---|---|---|
| Inyección | | 00:00 |
| Primer síntoma detectado | | |
| Fallo 1 diagnosticado / mitigado | | |
| Fallo 2 diagnosticado / mitigado | | |
| Fallo 3 diagnosticado / mitigado | | |
| `verify.sh` en verde | | |

**Mediana de tiempo hasta diagnóstico** — este es el número que vas a comparar.

## Por dónde empezar

Ahora tienes trece capas y doce grupos de comprobación. Úsalos:

```bash
# 1. ¿Qué ve un usuario?
curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' http://localhost:8080/api/checks

# 2. El harness cubre doce grupos. Empieza por ahí.
./platform/scripts/verify.sh

# 3. ¿Qué dicen los SLOs y las alertas?
# 4. ¿Y las trazas? ¿Dónde se corta el camino?
# 5. ¿Y lo que está por debajo de la aplicación? (módulo 08b)
# 6. Solo entonces, hacia los objetos concretos
```

El paso 5 es nuevo respecto al Game Day I, y hay al menos un fallo en el catálogo
que **solo** se ve ahí — la aplicación reporta latencias normales y el cliente
mide segundos.

## Al terminar

**No ejecutes `restore` todavía.**

1. Escribe tu diagnóstico de los tres.
2. `./scripts/gameday-2.sh status` para ver cuáles eran.
3. Ahora sí, lee el script y compara.

Y entonces:

4. **Abre tu `POSTMORTEM-1.md` del módulo 08c.** Compara la mediana de tiempo
   hasta diagnóstico. Trece semanas y seis capas más.

```bash
./scripts/gameday-2.sh restore
./platform/scripts/verify.sh
```
