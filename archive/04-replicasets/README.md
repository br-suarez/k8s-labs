# Lab 04: ReplicaSets

**Module:** 04 - ReplicaSets (optional)
**Date:** 2026-07-09

## Objective
Deploy a ReplicaSet to maintain a fixed number of nginx Pod replicas, and observe Kubernetes' self-healing behavior when a Pod is deleted manually.

## What I did

1. Created the ReplicaSet manifest (`replicaset.yaml`):

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx-replicaset-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-replicaset-demo
  template:
    metadata:
      labels:
        app: nginx-replicaset-demo
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

2. Applied it and verified:
```bash
kubectl apply -f replicaset.yaml
kubectl get replicasets
kubectl get pods -o wide
```

3. Tested self-healing by deleting a Pod manually:
```bash
kubectl delete pod nginx-replicaset-cns5q
kubectl get pods -o wide
```

## Issue encountered

On the first attempt, the ReplicaSet's `selector` used the same label (`app: nginx-demo`) as an existing standalone Pod from Lab 03 (`my-first-pod`). As a result:

- The ReplicaSet **adopted** the pre-existing `my-first-pod`, since ReplicaSets match Pods by label, not by name or origin.
- With the adopted Pod counted toward the desired replica count, the ReplicaSet only created 2 new Pods instead of 3 to reach the target of 3.

Confirmed via:
```bash
kubectl get pod my-first-pod -o yaml | grep -A5 ownerReferences
```
Output showed `my-first-pod` now had an `ownerReferences` entry pointing to the ReplicaSet — meaning it was no longer a standalone Pod, but under the ReplicaSet's control.

## Solution / Troubleshooting

Deleted the misconfigured ReplicaSet (which also removed the adopted Pod, since it was now owned by the ReplicaSet):
```bash
kubectl delete replicaset nginx-replicaset
```

Recreated it with a more specific, non-colliding label (`app: nginx-replicaset-demo` instead of the generic `app: nginx-demo` used in Lab 03). Re-applying confirmed exactly 3 Pods were created, all owned by the ReplicaSet, with no unintended adoption.

## Self-healing test

Deleted one of the three running Pods (`nginx-replicaset-cns5q`) manually:
NAME                     READY   STATUS    RESTARTS   AGE
nginx-replicaset-mln5p   1/1     Running   0          86s
nginx-replicaset-tlg4r   1/1     Running   0          86s
nginx-replicaset-x76sq   1/1     Running   0          6s

Within 6 seconds, the ReplicaSet controller created a replacement Pod (`nginx-replicaset-x76sq`), restoring the desired count of 3 — with no manual intervention.

## What I learned

- ReplicaSets identify and manage Pods purely through **label matching** (the `selector`), not by name or how the Pod was originally created. Any unowned Pod matching the selector gets adopted automatically.
- This is a real-world source of bugs: reusing generic labels across unrelated resources can cause a ReplicaSet (or later, a Deployment) to unexpectedly adopt — and eventually delete — Pods it shouldn't control.
- Best practice: use specific, resource-scoped labels rather than generic ones like `app: nginx-demo` across multiple manifests.
- Self-healing is automatic and fast: the ReplicaSet controller continuously reconciles the actual Pod count against the desired count, replacing terminated Pods within seconds.
