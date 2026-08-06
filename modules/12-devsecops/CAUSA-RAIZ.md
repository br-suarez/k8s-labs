# Causa raíz — Módulo 12

> Solo después de haber escrito tu diagnóstico.

## 1. Redis entró por la ventana del upgrade

```
helm upgrade kyverno → 3.3.0    2026-06-28 14:33:51
pod redis-0 creado              2026-06-28 14:34:17     ← 26 segundos después
```

Durante un `helm upgrade`, los pods del controlador de admisión se reemplazan.
Hay una ventana —normalmente de segundos a un par de minutos— en la que el
webhook no responde.

Con `failurePolicy: Ignore`, el API server ante un webhook que no contesta
**admite el recurso**. Sin error, sin aviso, sin evento. El pod entra como si la
política no existiera.

Y ahí se queda, porque el control de admisión no reevalúa nada.

## 2. `bitnami/kubectl` entró por la puerta principal

Distinto mecanismo, y más incómodo:

```yaml
verifyImages:
  - imageReferences: ["ghcr.io/br-suarez/*"]
```

Esa regla dice: *"para las imágenes que coincidan con `ghcr.io/br-suarez/*`,
verifica la firma"*. Una imagen de `docker.io` **no coincide con el patrón**, así
que la regla no aplica.

Y una regla que no aplica no rechaza: simplemente no opina. El pod se admite.

La política que creías tener era "todo debe estar firmado". La que escribiste es
"lo mío debe estar firmado, lo demás me da igual" — que es exactamente al revés
de lo que quieres, porque **el riesgo está en lo que no controlas**.

El arreglo:

```yaml
verifyImages:
  - imageReferences: ["*"]                    # todo
    skipImageReferences: []                   # sin excepciones implícitas
    attestors: [...]
```

Y si necesitas permitir imágenes de terceros concretas, se hace con una lista
explícita y auditable, no dejando un hueco por omisión.

## 3. La política no miente

`Ready: True` significa: *el controlador cargó la política y puede evaluarla.*
`Enforce` significa: *cuando evalúo y falla, rechazo.*

Ninguna de las dos afirma nada sobre lo que ya está corriendo. Las dos son
ciertas, y las dos son irrelevantes para la pregunta del auditor.

**El control de admisión es un control de flujo, no un control de estado.** Mira
lo que entra; no mira lo que hay. Es la distinción que hay que tener clara para
no confundir "tengo una política" con "cumplo la política".

## 4. `failurePolicy: Ignore` — la elección que hiciste

Elegiste **disponibilidad sobre seguridad**, probablemente sin decidirlo.

| | `Fail` | `Ignore` |
|---|---|---|
| Webhook caído | **Nada se despliega** | Todo se admite sin verificar |
| Riesgo | Indisponibilidad total del cluster | Hueco de seguridad silencioso |
| Cuándo muerde | Durante un incidente, cuando más necesitas desplegar | Durante un incidente, cuando nadie mira |

Es un intercambio real y no tiene una respuesta universal, que es por qué la
pregunta 7 dice que `Fail` no es obviamente correcto.

**El caso que lo hace incómodo:** un cluster que arranca entero desde cero. Con
`failurePolicy: Fail` y sin excluir los namespaces del sistema, el webhook de
Kyverno no puede arrancar porque su propio pod necesita pasar por... el webhook
de Kyverno. Deadlock de arranque, y hay que ir a mano a borrar la
`ValidatingWebhookConfiguration` para desbloquear el cluster.

Por eso las exclusiones de `kube-system` y `kyverno` que ya tienes son
imprescindibles, y por eso `Fail` exige haberlas pensado bien.

La postura defendible: **`Fail`, con exclusiones mínimas y explícitas para los
namespaces que arrancan el plano de control**, más alta disponibilidad del
webhook (varias réplicas, PDB) para que la ventana de indisponibilidad tienda a
cero. Es más trabajo y es la única que cierra el hueco.

## 5. `background: false` — el escaneo que no tenías

Con `background: true`, Kyverno evalúa periódicamente los recursos **ya
existentes** y genera `PolicyReport` con los que incumplen.

No los expulsa —sería peligroso— pero te los enseña. Con eso, redis habría
aparecido en un informe a los pocos minutos de colarse, en junio, en vez de en
una auditoría en agosto.

```bash
kubectl get policyreport -A
kubectl get clusterpolicyreport
```

Esto es lo que responde a la pregunta del auditor, y es la mitad del arreglo que
la gente olvida: **necesitas un control de flujo y un control de estado.** El
primero impide que entre; el segundo te dice qué hay.

## 6. El arreglo, en dos mitades

### Que no vuelva a pasar

```yaml
spec:
  validationFailureAction: Enforce
  background: true                          # ← escaneo de lo existente
  webhookConfiguration:
    failurePolicy: Fail                     # ← cierra la ventana
  rules:
    - name: check-signature
      match:
        any:
          - resources:
              kinds: [Pod]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]   # mínimas y justificadas
      verifyImages:
        - imageReferences: ["*"]            # ← todo, no solo lo tuyo
          attestors: [...]
```

Más: réplicas del controlador de admisión, un PDB, y `helm upgrade` con una
estrategia que no deje el webhook sin servir.

### Saber qué hay dentro ahora

```bash
# Inventario de todas las imágenes en ejecución
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' \
  | tr ' ' '\n' | sort -u

# Verificar cada una contra tu política de firma
while read -r img; do
  cosign verify "$img" --certificate-identity-regexp '.*' \
    --certificate-oidc-issuer-regexp '.*' >/dev/null 2>&1 \
    && echo "OK    $img" || echo "SIN FIRMA  $img"
done < <(kubectl get pods -A -o jsonpath='...' | tr ' ' '\n' | sort -u)
```

Eso va al harness como parte del grupo `security`, y se ejecuta periódicamente —
no solo cuando viene un auditor.

## Lo que se pregunta en entrevista sobre esto

No es "¿qué es un webhook de admisión?". Es: **"tienes una política de admisión
activa y algo que la incumple corriendo en producción. ¿Contradicción?"**

La respuesta: no. Admisión es un control de flujo con una ventana de fallo
configurable; el estado del cluster necesita un control aparte. Quien no
distingue las dos cosas cree que instalar Kyverno le dio cumplimiento, y lo que
le dio fue una puerta.
