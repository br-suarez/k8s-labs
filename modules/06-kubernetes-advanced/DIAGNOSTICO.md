# Diagnóstico — Módulo 06

**Tiempo: 40 min.** Sin documentación.

## Parte A — construir (25 min)

Cluster con Pulse corriendo del módulo 05. Convierte el almacenamiento en algo
serio:

1. Postgres como StatefulSet con `volumeClaimTemplates`, identidad estable y
   arranque ordenado.
2. Un `PodDisruptionBudget` para `pulse-api` que permita drenar un nodo sin
   perder servicio.
3. Anti-affinity que impida que las réplicas de `pulse-api` caigan en el mismo
   nodo.
4. Un `CronJob` (en `batch/v1`, no `v1beta1`) que haga backup de la base a un
   volumen `ReadWriteMany`.
5. El backup debe **verificarse a sí mismo**: si el dump está corrupto, el Job
   falla.

El punto 5 es el que separa. Casi todo el mundo escribe el backup; muy poca gente
escribe la comprobación.

## Parte B — razonar (15 min)

1. Un pod lleva 20 minutos en `Terminating`. Nombra las **cuatro** causas
   habituales y cómo distingues cada una.

2. Tienes un volumen NFS montado en tres pods. El servidor NFS deja de
   responder. ¿Qué le pasa a los procesos que estaban leyendo? ¿Por qué
   `kubectl delete pod --force` es peligroso aquí y qué hace exactamente?

3. ¿Diferencia entre `ReadWriteOnce`, `ReadWriteOncePod` y `ReadWriteMany`? Da
   un caso donde confundir los dos primeros cause corrupción.

4. Tu backup lleva seis meses ejecutándose y reportando éxito. ¿Qué tres cosas
   comprobarías **antes** de confiar en él en una restauración real?

## Criterio de aprobado

- Parte A: los 5 puntos, con el CronJob ejecutándose de verdad.
- Parte B: las cuatro. La 4 es eliminatoria — si tu respuesta no incluye "haber
  hecho una restauración completa", no has aprobado.

## Resultado

- **Aprobado** → labs 00, 03 y 05. (3 bloques)
- **No aprobado** → módulo completo. (5 bloques)

## Nota

Este módulo cubre lo que el `18.ParteII.md` del repo de referencia prometía y
nunca escribió: son diez viñetas sin contenido detrás. Todo aquí está construido
desde cero.
