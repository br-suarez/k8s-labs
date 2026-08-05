# Break-fix — Módulo 11

## El escenario

Llevas seis semanas con canary automático. Ha rechazado tres releases malos y
promovido cuarenta buenos. El equipo confía en él.

Ayer promovió un release que rompe el 100% de las peticiones a `/api/checks`.
Llegó al 100% de tráfico. La caída duró 22 minutos, hasta que un humano lo
revirtió a mano.

**El análisis pasó en los cuatro pasos.**

## Lo que ves

```
$ kubectl argo rollouts get rollout pulse-api -n pulse
Name:            pulse-api
Status:          ✔ Healthy
Strategy:        Canary
  Step:          8/8
  SetWeight:     100
  ActualWeight:  100

$ kubectl argo rollouts get rollout pulse-api -n pulse --watch  # del historial
STEP  ANALYSIS       RESULT       VALUE
1     error-rate     Successful   0.098
2     error-rate     Successful   0.291
3     error-rate     Successful   0.594
4     error-rate     Successful   0.981
```

Los valores **subieron en cada paso** y el análisis los dio por buenos las cuatro
veces.

## La configuración

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate
spec:
  metrics:
    - name: error-rate
      interval: 60s
      count: 3
      successCondition: result[0] < 1.0
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(pulse_http_requests_total{status=~"5.."}[2m]))
            /
            sum(rate(pulse_http_requests_total[2m]))
```

```yaml
strategy:
  canary:
    steps:
      - setWeight: 10
      - analysis: { templates: [{templateName: error-rate}] }
      - setWeight: 30
      - analysis: { templates: [{templateName: error-rate}] }
      - setWeight: 60
      - analysis: { templates: [{templateName: error-rate}] }
      - setWeight: 100
      - analysis: { templates: [{templateName: error-rate}] }
```

## Tu trabajo

1. Mira los cuatro valores: `0.098`, `0.291`, `0.594`, `0.981`. ¿Qué reconoces en
   esa progresión? Relaciónala con los pesos del canary.
2. Explica por qué el análisis pasó las cuatro veces. **Haz la aritmética.**
3. Hay un segundo defecto, independiente del primero, que por sí solo también
   habría dejado pasar el release. Encuéntralo.
4. Un tercero, más sutil, sobre `count` e `interval`.
5. Arréglalo. La consulta corregida debe dar ~1.0 en el primer paso.
6. Escribe la prueba que valida que tu análisis **detecta** un canary roto — sin
   esperar a que ocurra en producción.

## Pistas escalonadas

<details><summary>Pista 1</summary>

`0.098` con el canary al 10%. `0.291` con el canary al 30%. Divide el primer
valor entre el peso. ¿Qué te sale?
</details>

<details><summary>Pista 2</summary>

Lee la consulta con atención: `sum(rate(pulse_http_requests_total{...}))`.
¿Sobre qué pods está sumando? ¿Solo los del canary, o todos?
</details>

<details><summary>Pista 3 — para el punto 3</summary>

`successCondition: result[0] < 1.0`. La tasa de error es una **proporción entre 0
y 1**. ¿Qué valor tendría que alcanzar para que esa condición fuese falsa? ¿Es
alcanzable?
</details>

<details><summary>Pista 4 — para el punto 4</summary>

`interval: 60s`, `count: 3`, y la consulta usa `rate(...[2m])`. Cuando la primera
medición se ejecuta, ¿cuántos datos del canary hay dentro de esa ventana de 2
minutos?
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Un canary que rechaza releases malos genera confianza. Un canary que **parece**
funcionar y no discrimina genera confianza igual — y es peor que no tener
ninguno, porque el equipo deja de mirar.

Los tres defectos son independientes: arreglar uno solo no salva el release. Y
ninguno produce un error, un aviso ni un log. Todo está en verde mientras el
release rompe producción.
