# Lab 16.05 — ¿Cumplió la plataforma sus propios objetivos?

**CORE · 40 min**

## Contexto

Definiste SLOs en el módulo 07 y llevas trece semanas operando contra ellos. Esta
es la revisión que un equipo hace cada trimestre, y casi nadie hace bien.

## El ejercicio

### Parte 1 — el dato

Para cada SLI que definiste:

```promql
# Cumplimiento sobre todo el periodo
avg_over_time(pulse:api_availability:ratio[90d])

# Presupuesto de error consumido
1 - (avg_over_time(pulse:api_availability:ratio[90d]) / 0.999)
```

| SLI | Objetivo | Real | Presupuesto consumido |
|---|---|---|---|
| Disponibilidad de la API | | | |
| Latencia p99 | | | |
| Frescura de sondeos | | | |
| Durabilidad de resultados | | | |

1. ¿Cuáles cumpliste? ¿Cuáles no?
2. ¿Dónde se fue el presupuesto? ¿Incidentes, despliegues, o los propios Game
   Days?

La pregunta 2 tiene una respuesta incómoda: **tus ejercicios consumieron
presupuesto real.** Eso es correcto y hay que contarlo — un Game Day que no
consume presupuesto probablemente no estaba probando nada.

### Parte 2 — ¿eran los objetivos correctos?

3. ¿Algún SLO se cumplió con muchísimo margen todo el tiempo? Eso sugiere que era
   demasiado laxo, y un SLO que nunca se acerca a su límite no informa ninguna
   decisión.
4. ¿Alguno se incumplió constantemente? ¿El objetivo era irreal o el sistema
   insuficiente?
5. ¿Algún SLI resultó no medir lo que creías? Vuelve al módulo 07: el problema de
   "¿de quién es el fallo?" ¿se resolvió bien?

### Parte 3 — la conversación de coste

Con el coste por unidad del módulo 14:

6. ¿Cuánto costó el nivel de fiabilidad que conseguiste?
7. ¿Cuánto costaría un nueve más? Estímalo con números reales.
8. ¿Lo recomendarías? ¿Contra qué lo compararías?

La pregunta 8 es la que convierte a un SRE en alguien que participa en decisiones
de producto en vez de recibirlas.

### Parte 4 — la revisión

Escribe `platform/SLO-REVIEW.md`, en inglés, como se lo presentarías a un equipo:

1. Cumplimiento por SLI, con el dato
2. Dónde se consumió el presupuesto
3. Qué objetivos ajustarías y por qué
4. Qué SLI eliminarías por no informar ninguna decisión
5. Qué SLI falta
6. El coste de la fiabilidad actual y del siguiente escalón

El punto 4 es el que se omite siempre. Un SLI que nadie ha mirado nunca para
decidir algo es un panel bonito, no un objetivo de servicio.

## Expected outcome

`SLO-REVIEW.md` con datos reales de todo el periodo, una recomendación de ajuste
por SLI, y el coste del siguiente nivel de fiabilidad estimado.
