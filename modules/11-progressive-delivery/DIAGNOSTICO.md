# Diagnóstico — Módulo 11

**Tiempo: 35 min.** Sin documentación.

## Parte A — construir (20 min)

Con Pulse en Argo CD y el SLO del módulo 07 definido:

1. Convierte el Deployment de `pulse-api` en un `Rollout` de Argo Rollouts con
   estrategia canary.
2. Pasos: 10% → 30% → 60% → 100%, con análisis entre cada uno.
3. Un `AnalysisTemplate` que consulte la tasa de error del canary contra
   Prometheus.
4. Rollback automático si el análisis falla.
5. El reparto de tráfico debe usar el Gateway API del módulo 05, no réplicas.

El punto 5 es el que separa. Repartir por número de réplicas es una aproximación
burda y se rompe con pocas réplicas.

## Parte B — razonar (15 min)

1. Tu canary tiene pausas de 30 s y la métrica se calcula sobre una ventana de
   5 minutos. ¿Qué está mal y cómo se manifiesta?

2. La consulta del análisis es:
   ```promql
   sum(rate(pulse_http_requests_total{status=~"5.."}[2m]))
   / sum(rate(pulse_http_requests_total[2m]))
   ```
   El canary tiene el 10% del tráfico y falla el **100%** de sus peticiones. El
   umbral de rechazo es 5%. ¿Se rechaza el release? Calcula.

3. Canary vs blue/green. Da un workload donde blue/green sea claramente mejor.

4. ¿Qué pasa con las conexiones en vuelo hacia los pods del canary cuando se
   aborta un rollout?

## Criterio de aprobado

- Parte A: los 5 puntos, con un rollback automático demostrado.
- Parte B: las cuatro. **La 2 es eliminatoria** — es el break-fix, y si no haces
  la aritmética te va a parecer que está bien.

## Resultado

- **Aprobado** → labs 00, 03 y 04. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Nota

El módulo 21 de `archive/sre-track/` ya hizo un canary con rechazo automático y
encontró el bug de blast radius por pausa corta. Si apruebas el diagnóstico,
sáltate la mecánica y ve directo al lab 04 y al break-fix — que atacan un error
distinto y más sutil.
