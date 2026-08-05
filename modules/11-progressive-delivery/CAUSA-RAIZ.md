# Causa raíz — Módulo 11

> Solo después de haber hecho la aritmética.

## 1. La progresión

```
paso 1: canary al 10%  → valor 0.098
paso 2: canary al 30%  → valor 0.291
paso 3: canary al 60%  → valor 0.594
paso 4: canary al 100% → valor 0.981
```

Divide cada valor entre su peso:

```
0.098 / 0.10 = 0.98
0.291 / 0.30 = 0.97
0.594 / 0.60 = 0.99
0.981 / 1.00 = 0.98
```

**La tasa de error del canary es ~1.0 en los cuatro pasos.** Rompía el 100% desde
el principio.

Lo que estabas midiendo no era la tasa de error del canary: era la tasa de error
**global**, que es la del canary diluida por el tráfico sano del stable.

```
error_global = peso_canary × error_canary + (1 − peso_canary) × error_stable
             = 0.10 × 1.0 + 0.90 × 0
             = 0.10
```

El número que veías era, casi exactamente, el peso del canary. Esa es la firma
del bug, y una vez la reconoces se detecta en diez segundos.

## 2. Defecto A — la consulta no está acotada al canary

```promql
sum(rate(pulse_http_requests_total{status=~"5.."}[2m]))
/
sum(rate(pulse_http_requests_total[2m]))
```

`sum` sin `by` ni filtro agrega **todos los pods** de `pulse-api`: canary y
stable juntos. Cuanto menos tráfico tiene el canary, más se diluye su fallo — es
decir, **el análisis es menos sensible justo cuando más protección necesitas**,
en el primer paso.

Con el canary al 10%, un fallo del 100% se ve como un 10%. Con el canary al 1%,
como un 1%. La aproximación destruye exactamente la señal que buscas.

### El arreglo

Argo Rollouts inyecta el hash del pod template del canary como argumento:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate
spec:
  args:
    - name: canary-hash
  metrics:
    - name: error-rate
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(pulse_http_requests_total{
              status=~"5..",
              rollouts_pod_template_hash="{{args.canary-hash}}"
            }[2m]))
            /
            sum(rate(pulse_http_requests_total{
              rollouts_pod_template_hash="{{args.canary-hash}}"
            }[2m]))
```

Y en el Rollout:

```yaml
- analysis:
    templates: [{templateName: error-rate}]
    args:
      - name: canary-hash
        valueFrom:
          podTemplateHashValue: Latest
```

**Requisito que se olvida:** para que ese filtro funcione, la métrica tiene que
llevar la etiqueta `rollouts_pod_template_hash`. No aparece sola — hay que
propagarla desde las etiquetas del pod en el `ServiceMonitor`:

```yaml
podTargetLabels:
  - rollouts-pod-template-hash
```

Si te saltas esto, la consulta filtra por una etiqueta inexistente, **devuelve
vacío**, y entonces te muerde el defecto C.

## 3. Defecto B — el umbral es inalcanzable

```yaml
successCondition: result[0] < 1.0
```

La tasa de error es una proporción entre 0 y 1. La condición "menor que 1.0" solo
es falsa si **el 100% de todas las peticiones del cluster fallan**, y ni siquiera
entonces con seguridad: el último paso midió `0.981` y pasó.

Escrito de otra forma: esa condición dice "acepta cualquier cosa salvo la
catástrofe total". No es un umbral, es un adorno.

```yaml
successCondition: result[0] < 0.05     # 5%, coherente con el SLO del módulo 07
```

El número debe salir del SLO, no de la intuición. Si tu SLO de disponibilidad es
99.9%, un canary al 5% de error está quemando presupuesto a 50x.

**Este defecto solo habría bastado para dejar pasar el release**, incluso con la
consulta bien acotada. Por eso hay que arreglar los tres.

## 4. Defecto C — la ventana y el momento de la medición

```yaml
interval: 60s
count: 3
```
con `rate(...[2m])`.

La primera medición se ejecuta nada más entrar en el paso de análisis. En ese
momento, la ventana de 2 minutos contiene sobre todo tráfico **anterior a que el
canary existiera**. El canary lleva vivo segundos.

Resultado: la primera de las tres mediciones está calculada sobre datos que casi
no contienen al canary. Y con `failureLimit: 1`, el análisis tolera un fallo de
tres — así que basta con que esa primera medición diluida pase para inclinar el
resultado.

Y hay un caso peor: si el canary aún no ha servido **ninguna** petición, el
denominador es cero, la consulta devuelve `NaN` o vacío, y el comportamiento por
defecto ante un resultado vacío puede ser tratarlo como no concluyente en vez de
como fallo.

### El arreglo

```yaml
metrics:
  - name: error-rate
    initialDelay: 2m        # que la ventana se llene de datos del canary
    interval: 60s
    count: 5
    successCondition: result[0] < 0.05
    failureLimit: 0         # un solo fallo aborta
    provider:
      prometheus:
        query: |
          sum(rate(...{rollouts_pod_template_hash="{{args.canary-hash}}"}[2m]))
          /
          clamp_min(sum(rate(...{rollouts_pod_template_hash="{{args.canary-hash}}"}[2m])), 1)
```

Cuatro cambios:

- `initialDelay: 2m` — igual o mayor que la ventana del `rate`. **La regla: la
  pausa antes de medir nunca debe ser menor que la ventana de la métrica.** Es la
  misma lección del bug de blast radius del módulo 21 de `archive/`, desde el
  otro lado.
- `count: 5` en vez de 3, para más muestras independientes.
- `failureLimit: 0` — con un umbral correcto, una sola violación debe abortar.
- `clamp_min` en el denominador para que la ausencia de tráfico no produzca `NaN`.

## 5. Verificación

Con los tres arreglos, el primer paso debe medir ~1.0 y rechazar:

```
STEP  ANALYSIS     RESULT   VALUE
1     error-rate   Failed   0.987
```

Y el rollout aborta en el paso 1, con el canary al 10%. Blast radius: 10% del
tráfico durante `initialDelay` + una medición ≈ 3 minutos, en vez del 100%
durante 22.

## 6. La prueba que valida el análisis

Esto es lo que faltaba, y es lo más importante del arreglo.

**Tu análisis nunca se probó contra un canary roto.** Se probó implícitamente
contra releases buenos, que pasaban, y de ahí se concluyó que funcionaba.

```bash
#!/usr/bin/env bash
# scripts/verify-canary-analysis.sh
# Despliega deliberadamente un canary roto y exige que el análisis lo rechace.
set -euo pipefail

kubectl argo rollouts set image pulse-api \
  pulse-api="$BROKEN_IMAGE_DIGEST" -n pulse

# Debe abortar, no promover
if kubectl argo rollouts status pulse-api -n pulse --timeout=10m; then
  echo "FAIL: el análisis promovió un canary que rompe el 100% de las peticiones"
  kubectl argo rollouts undo pulse-api -n pulse
  exit 1
fi

echo "OK: el análisis rechazó el canary roto"
kubectl argo rollouts get rollout pulse-api -n pulse | grep -i degraded
```

Se ejecuta en CI, contra una imagen rota que mantienes a propósito. **Un canary
cuyo rechazo nunca se ha demostrado es una hipótesis**, exactamente igual que un
backup que nunca se ha restaurado en el módulo 06.

Esa simetría no es casual: en los dos casos el sistema reporta éxito por defecto,
y solo una prueba que fuerce el camino de fallo demuestra que el mecanismo
existe.
