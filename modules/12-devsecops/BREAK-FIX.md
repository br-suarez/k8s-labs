# Break-fix — Módulo 12

## El escenario

Auditoría de seguridad. El auditor ejecuta un inventario de lo que corre en el
cluster y te enseña esto:

```
$ kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | sort -u
pulse       ghcr.io/br-suarez/pulse-api@sha256:9f2c4a...
pulse       ghcr.io/br-suarez/pulse-worker@sha256:c7d1e5...
pulse       ghcr.io/br-suarez/pulse-web@sha256:3a8f01...
pulse       docker.io/library/redis:7-alpine          ← sin firmar
pulse-ops   docker.io/bitnami/kubectl:latest          ← sin firmar
```

Dos imágenes públicas, sin firma, corriendo en producción.

Tu política de admisión existe y está sana:

```
$ kubectl get clusterpolicy require-signed-images
NAME                     ADMISSION   BACKGROUND   READY   AGE
require-signed-images    true        false        True    47d

$ kubectl get pods -n kyverno
NAME                                 READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-0        1/1     Running   0          6d
```

Y funciona — si intentas desplegar esa **misma** imagen ahora:

```
$ kubectl run test --image=docker.io/library/redis:7-alpine -n pulse
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
  resource Pod/pulse/test was blocked due to the following policies

  require-signed-images:
    check-signature: 'failed to verify signature for docker.io/library/redis:7-alpine: no matching signatures'
```

## Los datos que tienes

```
$ kubectl get clusterpolicy require-signed-images -o yaml | head -30
spec:
  validationFailureAction: Enforce
  background: false
  webhookConfiguration:
    failurePolicy: Ignore
  rules:
    - name: check-signature
      match:
        any:
          - resources:
              kinds: [Pod]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]
      verifyImages:
        - imageReferences: ["ghcr.io/br-suarez/*"]
          attestors: [...]
```

Historial del cluster:

```
$ kubectl get events -A --field-selector reason=Killing -o wide 2>/dev/null | head -3
$ helm history kyverno -n kyverno
REVISION  UPDATED                   STATUS      CHART           DESCRIPTION
1         2026-06-16 09:12:04       superseded  kyverno-3.2.1   Install complete
2         2026-06-28 14:33:51       superseded  kyverno-3.3.0   Upgrade complete
3         2026-07-19 11:07:22       deployed    kyverno-3.4.2   Upgrade complete

$ kubectl get pod redis-0 -n pulse -o jsonpath='{.metadata.creationTimestamp}'
2026-06-28T14:34:17Z
```

## Tu trabajo

1. ¿Cómo entró `redis:7-alpine`? La marca de tiempo te lo dice — explícalo.
2. `bitnami/kubectl:latest` en `pulse-ops` entró de otra forma. ¿Cuál? Mira el
   `imageReferences` de la política.
3. **La pregunta central:** ¿por qué la política sigue diciendo `Ready: True` y
   `Enforce` si hay imágenes sin firmar corriendo? ¿Está mintiendo?
4. `failurePolicy: Ignore`. ¿Qué elegiste con eso, sabiéndolo o no?
5. `background: false`. ¿Qué te habría dado ponerlo a `true`?
6. Arréglalo. Necesitas resolver dos cosas distintas: que no vuelva a pasar, y
   saber qué hay dentro **ahora**.
7. `failurePolicy: Fail` habría cerrado el hueco del punto 1. ¿Por qué no es
   obviamente la respuesta correcta?

## Pistas escalonadas

<details><summary>Pista 1</summary>

Compara la marca de tiempo del pod de redis con la del `helm history`. ¿Qué
estaba pasando en el cluster a las 14:33 del 28 de junio?
</details>

<details><summary>Pista 2</summary>

El control de admisión se llama así por algo: actúa en el momento de la
**admisión**. ¿Qué le pasa a un recurso que ya está dentro cuando cambias la
política, o cuando la política no estaba disponible?
</details>

<details><summary>Pista 3 — para el punto 2</summary>

`imageReferences: ["ghcr.io/br-suarez/*"]`. ¿Qué imágenes evalúa esa regla?
¿Y qué hace con una imagen que no coincide con ese patrón?

Ojo: no las rechaza. Las **ignora**.
</details>

<details><summary>Pista 4 — para el punto 7</summary>

Si el webhook debe responder para que cualquier pod se admita, ¿qué pasa cuando
el webhook está caído? Piensa en un cluster que se reinicia entero y en qué orden
arrancan las cosas.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Porque enseña la propiedad que define el control de admisión y que casi nadie
enuncia: **es una puerta, no una garantía.** Todo lo que ya está dentro sigue
dentro, y la puerta tiene horarios de apertura que tú configuraste sin darte
cuenta.
