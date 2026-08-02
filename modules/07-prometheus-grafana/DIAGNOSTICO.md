# Diagnóstico — Módulo 07

**Tiempo: 40 min.** Sin documentación. PromQL de memoria.

## Parte A — consultar (20 min)

Dado que `pulse-api` expone `pulse_http_requests_total{method,path,status}` y
`pulse_http_request_duration_seconds` (histograma), escribe de memoria:

1. Tasa de peticiones por segundo, por path, en los últimos 5 minutos.
2. Proporción de errores (5xx sobre total), por path.
3. Percentil 99 de latencia, por path.
4. Una regla de grabación que haga que la consulta 3 sea instantánea en un panel
   de 30 días.
5. Una alerta de burn rate multiventana para un SLO de disponibilidad del 99,9%.
6. Consulta que devuelva las 5 métricas con más series activas.

## Parte B — razonar (20 min)

1. `rate()` vs `irate()` vs `increase()`. ¿Cuál usas para una alerta y por qué
   los otros dos son mala idea ahí?

2. Tu panel de p99 tarda 8 segundos. Nombra las **tres** causas posibles y cómo
   distingues entre ellas.

3. Un compañero propone añadir la etiqueta `url` a
   `pulse_probe_duration_seconds`, para poder filtrar por endpoint sondeado.
   Pulse monitoriza 40.000 endpoints. ¿Qué le respondes, con números?

4. Defines un SLI de disponibilidad para Pulse como "porcentaje de sondeos
   exitosos". Explica por qué está mal.

5. `histogram_quantile(0.99, ...)` sobre un histograma con buckets
   `[0.1, 0.5, 1, 5]` y una latencia real de p99 = 2,3 s. ¿Qué valor devuelve y
   por qué?

## Criterio de aprobado

- Parte A: las 6. La 4 y la 5 son las que separan.
- Parte B: las cinco. **La 3 y la 4 son eliminatorias** — son los dos errores que
  más caro salen en producción.

## Resultado

- **Aprobado** → labs 00, 03 y 04. (2 bloques)
- **No aprobado** → módulo completo. (4 bloques)

## Nota

El módulo 29 de `archive/sre-track/` cubre PromQL y alerting, y el 20 cubre
burn rate. Lo que probablemente no cubren: el stack en-cluster con el Operator,
las reglas de grabación medidas, y la pregunta 3 sobre cardinalidad — que es el
break-fix de este módulo.
