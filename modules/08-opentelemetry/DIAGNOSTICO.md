# Diagnóstico — Módulo 08

**Tiempo: 30 min.** Corto a propósito, como el del módulo 05.

## Aviso

Junto con Gateway API, este es el módulo donde **suspender es lo normal**.
OpenTelemetry no aparece en ninguno de los repos de referencia — cero cobertura,
verificado. Si lo suspendes no dice nada de tu nivel; dice por qué este módulo
tiene 6 bloques.

Hazlo igualmente para saber dónde estás.

## Prueba

Sin documentación:

1. Nombra las tres señales de OpenTelemetry y di qué recurso las une para poder
   correlacionarlas.

2. ¿Qué es el *context propagation* y qué formato estándar usa OTel por defecto
   sobre HTTP? Escribe la cabecera de memoria, con su estructura.

3. `pulse-api` encola un trabajo en Redis. `pulse-worker` lo recoge 40 segundos
   después. Explica **por qué** la traza se rompe aquí y qué hay que hacer para
   que no.

4. ¿Diferencia entre head sampling y tail sampling? Da un requisito que solo se
   pueda cumplir con tail sampling.

5. El Collector tiene receivers, processors y exporters. ¿Qué hace
   `memory_limiter` y por qué el orden en el que aparece en el pipeline importa?

6. Tienes un pico de latencia en un panel de Grafana. ¿Qué mecanismo te lleva de
   ese punto del gráfico a la traza concreta que lo causó?

## Criterio de aprobado

Las seis. **La 3 y la 6 son eliminatorias**: la 3 es el problema central del
módulo y la 6 es el pago de haber hecho el módulo 07.

## Resultado

- **Aprobado** → labs 00, 04, 05 y 06. (3 bloques)
- **No aprobado** → módulo completo. (6 bloques)

## Nota

Si has usado auto-instrumentación en algún sitio, ojo: es probable que apruebes
la 1, la 2 y la 5 sin haber escrito nunca un span a mano. La 3 es la que
distingue haber configurado OTel de haberlo entendido.
