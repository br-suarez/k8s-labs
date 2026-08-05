# Causa raíz — Módulo 10

> Solo después de haber escrito tu diagnóstico.

## 1. Los tres minutos

Argo CD reconcilia cada **180 segundos** por defecto
(`timeout.reconciliation` en `argocd-cm`). En cada ciclo compara el estado
deseado —Git— con el real, y con `selfHeal: true` aplica el manifiesto de Git
sobre lo que encuentre.

Tu parche a 512Mi sobrevive hasta la siguiente reconciliación. Entonces Argo
aplica el Deployment tal y como está en Git, con `256Mi`, los pods se recrean, y
vuelven a morir por OOM.

**El controlador no está roto. Está haciendo exactamente lo que le pediste**: que
el cluster sea una consecuencia del repositorio. Tu cambio no estaba en el
repositorio, así que no era parte de la verdad.

Es el ciclo más frustrante de operar GitOps, y le pasa a todo el mundo una vez.

## 2. Por qué dice `Synced`

Aquí hay una sutileza que mucha gente entiende al revés.

```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/template/spec/containers/0/resources
```

`ignoreDifferences` afecta a la **comparación**, no a la aplicación. Le dice a
Argo: "al calcular el estado de sincronización, no mires este campo".

Con lo cual:

- Tu parche a 512Mi → Argo no mira `resources` → **no ve diferencia** → `Synced`
- `selfHeal` se dispara igualmente en cada ciclo y aplica el manifiesto completo
  de Git, incluidos los `resources` que dijiste ignorar

Resultado: Argo te dice que todo está sincronizado mientras revierte activamente
tu cambio. **La diferencia está oculta, no ausente.**

Y la respuesta a la segunda mitad de la pregunta 2: sin `ignoreDifferences` Argo
diría `OutOfSync` durante unos segundos y luego `Synced` tras revertir. También
verde la mayor parte del tiempo. El panel nunca iba a decirte lo que pasaba.

**Regla:** `ignoreDifferences` es para campos que otro controlador legítimamente
gestiona —réplicas bajo un HPA, anotaciones inyectadas por un webhook—. Usarlo
para silenciar una diferencia que te molesta convierte tu panel en un mentiroso.

## 3. Por qué dice `Healthy`

Distinto bug, distinta causa.

Argo evalúa la salud de un Deployment con una regla propia basada en sus
condiciones: mira `Progressing` con razón `NewReplicaSetAvailable`, y compara
`status.availableReplicas` con lo esperado.

El problema es el tiempo. Un Deployment cuyos pods reinician en bucle **no se
marca como fallido inmediatamente**: Kubernetes espera
`progressDeadlineSeconds` (600 por defecto) antes de poner la condición
`Progressing=False` con razón `ProgressDeadlineExceeded`.

Durante esos diez minutos, el Deployment está formalmente "progresando". Y como
Argo reinicia el ciclo cada tres minutos creando un ReplicaSet nuevo, **el reloj
de los 600 segundos nunca llega al final**.

El sistema está permanentemente a punto de darse cuenta de que está roto, y nunca
le da tiempo.

Arreglo:

```yaml
spec:
  progressDeadlineSeconds: 120     # en el Deployment
```

Con 120s, un rollout que no converge se marca como fallido antes del siguiente
ciclo de reconciliación, y Argo lo reporta `Degraded`.

## 4. Mitigación a las 03:10

Tres opciones, de menor a mayor alcance. **Elige la primera que resuelva.**

```bash
# a) Desactivar self-heal solo en esta Application  ← la correcta
argocd app set pulse --self-heal=false

# b) Detener toda la sincronización de esta Application
argocd app set pulse --sync-policy none

# c) Escalar el controlador a cero  ← afecta a TODAS las apps del cluster
kubectl scale deployment argocd-application-controller -n argocd --replicas=0
```

La **(a)**. Deja el resto de aplicaciones gobernadas, conserva la detección de
drift —Argo te seguirá diciendo `OutOfSync`, que es información útil— y solo
suspende la corrección automática de esta.

La (c) es la que la gente hace bajo presión y es la peor: apaga el gobierno de
todo el cluster, y alguien tiene que acordarse de volver a encenderlo.

Después de mitigar, **el arreglo va a Git**:

```bash
# En el overlay de prod
kustomize edit set ... # o editar el patch de recursos
git commit -m "Raise pulse-api memory limit to 512Mi after OOM incident"
git push
argocd app set pulse --self-heal=true
argocd app sync pulse
```

## 5. El arreglo completo

Tres cambios:

1. **El límite de memoria, en Git.** Es la corrección real.
2. **Quitar el `ignoreDifferences`.** No había ninguna razón legítima para él, y
   estaba ocultando exactamente el campo del incidente.
3. **`progressDeadlineSeconds: 120`** para que un rollout roto se reporte como
   `Degraded` en vez de "progresando" indefinidamente.

Y una cuarta, opcional pero recomendable: una alerta sobre el estado de las
Applications de Argo, para que `Degraded` u `OutOfSync` sostenido generen una
notificación en vez de esperar a que alguien mire el panel.

## 6. El procedimiento de emergencia

Esto es lo que hay que tener escrito **antes** de necesitarlo.

```markdown
## Emergency change procedure

GitOps says the cluster follows Git. During an incident that is sometimes too
slow, and the procedure below is how you go around it without fighting the
controller.

1. Disable self-heal for the affected Application ONLY:
       argocd app set <app> --self-heal=false
   Never scale down the controller — that removes governance cluster-wide.

2. Apply the minimum change that restores service.

3. Announce it: incident channel, one line, what you changed and why.
   An undeclared manual change is how the next person loses two hours.

4. Open a PR with the same change BEFORE the incident is closed.
   The incident is not closed until Git and the cluster agree.

5. Re-enable self-heal and sync:
       argocd app set <app> --self-heal=true
       argocd app sync <app>

6. In the postmortem, ask: why was the change urgent enough to bypass Git?
   If the answer is "the pipeline takes 20 minutes", that is the real finding.
```

Ese último punto es el que más vale. Saltarse GitOps repetidamente no es un
problema de disciplina: es la señal de que el camino normal es demasiado lento, y
eso sí se puede arreglar.
