# Break-fix — Módulo 10

## El escenario

02:47. Te paginan: `pulse-api` en CrashLoopBackOff, OOMKilled.

Diagnosticas rápido — el límite de memoria se quedó corto tras el cambio de la
semana pasada. Parcheas:

```bash
kubectl set resources deployment/pulse-api -n pulse --limits=memory=512Mi
```

Los pods arrancan. El servicio vuelve. Cierras el incidente a las 02:53 y te
vuelves a dormir.

**03:01** — te paginan otra vez. Mismo error.

Vuelves a parchear. Funciona. **03:07** — otra vez.

A la tercera te quedas mirando. El servicio se cae aproximadamente **cada tres
minutos**, y tu arreglo desaparece cada vez.

## Lo que ves

```
$ kubectl get deployment pulse-api -n pulse -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
256Mi

$ kubectl get events -n pulse --sort-by=.lastTimestamp | tail -6
2m   Normal   ScalingReplicaSet   deployment/pulse-api   Scaled up replica set pulse-api-6f8c to 3
2m   Warning  BackOff             pod/pulse-api-6f8c-x2k   Back-off restarting failed container
5m   Normal   ScalingReplicaSet   deployment/pulse-api   Scaled up replica set pulse-api-7a1d to 3
5m   Warning  BackOff             pod/pulse-api-7a1d-9mz   Back-off restarting failed container
```

Y en Argo CD:

```
$ argocd app get pulse
Name:         pulse
Health Status: Healthy
Sync Status:   Synced to  a3f9c21 (a3f9c21)
```

**`Healthy`. `Synced`.** Con los pods en CrashLoopBackOff.

## La configuración de la Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pulse
spec:
  project: default
  source:
    repoURL: https://github.com/br-suarez/devops-sre-mastery.git
    path: platform/deploy/k8s/overlays/prod
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: pulse
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/template/spec/containers/0/resources
```

## Tu trabajo

1. Explica por qué tu arreglo desaparece cada tres minutos. Sé preciso sobre el
   mecanismo y sobre el número.
2. ¿Por qué Argo dice `Synced` si el cluster tiene un límite de memoria distinto
   al de Git... y por qué **también** lo diría si no lo tuviera?
3. ¿Por qué dice `Healthy` con los pods en CrashLoopBackOff? Esto es un bug
   distinto del anterior.
4. **Mitiga.** Son las 03:10, sigues de guardia. ¿Qué haces *ahora* para parar el
   ciclo, sin romper GitOps para todo lo demás?
5. Arréglalo de verdad.
6. Escribe el procedimiento de emergencia: cómo debe un humano saltarse GitOps a
   las 3am de forma auditable, sin pelearse con el controlador.

## Pistas escalonadas

<details><summary>Pista 1</summary>

Tres minutos es un número por defecto de Argo CD, no una casualidad. ¿Cada cuánto
reconcilia una Application con `automated` activado?
</details>

<details><summary>Pista 2 — para el punto 2</summary>

Lee `ignoreDifferences` otra vez, campo por campo. ¿Qué le estás diciendo
exactamente a Argo que ignore al **comparar**? ¿Y qué hace `selfHeal` con lo que
no ignora?

Ojo con la trampa: ignorar una diferencia hace que Argo no la *reporte*, pero
`selfHeal` sigue aplicando el manifiesto completo de Git.
</details>

<details><summary>Pista 3 — para el punto 3</summary>

Argo evalúa la salud de un Deployment a partir de sus condiciones y de
`status.availableReplicas`. Busca cuánto tiempo tarda `progressDeadlineSeconds`
en marcar un Deployment como fallido, y qué reporta Argo mientras tanto.
</details>

<details><summary>Pista 4 — para el punto 4</summary>

Hay tres formas de parar el ciclo, con distinto alcance y distinto coste. Una
afecta solo a esta aplicación, otra a este recurso, y otra a todo el cluster.
Elige la de menor alcance que resuelva el problema.
</details>

Causa raíz en `CAUSA-RAIZ.md`.

## Por qué este break-fix está aquí

Es el momento en que GitOps deja de ser una idea bonita y se convierte en algo
que hay que **operar**. El controlador no está roto: está haciendo exactamente su
trabajo, y su trabajo es deshacer lo que hiciste. Entender eso antes de vivirlo a
las 3am vale bastante.
