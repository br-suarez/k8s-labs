# Lab 10.01 — Bootstrap, and what it did to your cluster

**CORE · 40 min**

## Context

Installing Argo CD is one command. Understanding what that command put in your
cluster, and what it can now do, is the lab.

## The problem

### Part 1 — install and inspect

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.6/manifests/install.yaml
kubectl wait --for=condition=Available --timeout=300s deployment --all -n argocd
```

Before touching the UI, account for what arrived:

```bash
kubectl get all -n argocd
kubectl get crd | grep argoproj
kubectl get clusterrole,clusterrolebinding | grep argocd
```

Answer in `NOTAS.md`:

1. Name every Deployment and say in one line what it does.
2. What CRDs were added?
3. **What ClusterRole does the application-controller have?** Read it properly.
   What can it do to your cluster?
4. Given that answer, what happens if someone compromises the controller?

Question 3 is the one people skip. You just installed something with very broad
permissions, and knowing exactly how broad is part of running it.

### Part 2 — reach it

```bash
argocd admin initial-password -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd login localhost:8080 --username admin --insecure
```

5. Why does the server need `--insecure` here? What would you do in production?
6. Change the admin password and disable the initial secret. Why does it matter
   that the initial one is stored in a Secret in plain form?

### Part 3 — the first Application

Deploy Pulse from Git — the manifests you wrote in module 04, unchanged for now.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pulse
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/devops-sre-mastery.git
    path: platform/deploy/k8s
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: pulse
  syncPolicy:
    automated: { prune: false, selfHeal: false }
```

Note `prune` and `selfHeal` are **off**. Turn them on deliberately in lab 04,
after you understand what they do.

7. Sync manually. What did Argo do, in what order, and how did it decide?
8. `argocd app diff pulse` — what does it show before and after?

## Expected outcome

Argo CD running, Pulse deployed from Git, and the eight questions answered —
especially question 3.

## Staged hints

<details><summary>Hint 1 — question 3</summary>

By default the application-controller gets `cluster-admin`, because it must be
able to create any resource type an Application might contain. That is a lot of
authority for one workload. Reducing it means restricting Argo to specific
namespaces and resource kinds via AppProjects — real work, and the reason
`argocd-rbac-cm` and AppProjects exist.
</details>

<details><summary>Hint 2 — question 4</summary>

Whoever controls the controller controls the cluster, and can do it *through a
legitimate mechanism* that looks like normal reconciliation. That is why the
repo Argo watches is a production-critical asset: write access to it is
effectively write access to the cluster.
</details>
