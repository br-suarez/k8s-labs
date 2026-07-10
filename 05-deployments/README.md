# Lab 05: Deployments

**Module:** 05 - Deployments
**Date:** 2026-07-09

## Objective
Deploy an nginx application using a Deployment (instead of a bare ReplicaSet), and exercise its two core capabilities: zero-downtime rolling updates and rollback.

## What I did

1. Created the Deployment manifest (`deployment.yaml`), starting from a pinned version (`nginx:1.25`) rather than `latest`, to have a clean baseline for testing updates:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx-deployment-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-deployment-demo
  template:
    metadata:
      labels:
        app: nginx-deployment-demo
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

2. Applied it and verified the Deployment created a ReplicaSet automatically:
```bash
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl get replicasets
kubectl get pods -o wide
```

3. Triggered a rolling update to `nginx:1.26`:
```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.26
kubectl rollout status deployment/nginx-deployment
```

4. Verified the update happened gradually (never dropping below 2 available replicas):
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 old replicas are pending termination...
deployment "nginx-deployment" successfully rolled out

5. Confirmed a new ReplicaSet was created for the new version, while the old one was kept (scaled to 0) for rollback purposes:
```bash
kubectl get replicasets
```
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-57c67cf74d   3         3         3       2m3s
nginx-deployment-854d55664f   0         0         0       32m

6. Tested rollback to the previous version:
```bash
kubectl rollout undo deployment/nginx-deployment
kubectl rollout status deployment/nginx-deployment
kubectl get pods -o wide
```
Confirmed the Deployment reused the original ReplicaSet (`854d55664f`, nginx:1.25) instead of creating a new one — this is how revision history works under the hood.

## Issue encountered

`kubectl rollout history deployment/nginx-deployment` showed `CHANGE-CAUSE: <none>` for every revision, making it impossible to tell *why* each revision was created just from the history output.

Attempted to fix it using the documented `--record` flag:
```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.26 --record
```
This worked, but returned a deprecation warning:
Flag --record has been deprecated, --record will be removed in the future

## Solution / Troubleshooting

`--record` still works but is deprecated and will be removed in a future kubectl version. The modern approach is to annotate the change-cause manually:
```bash
kubectl annotate deployment/nginx-deployment kubernetes.io/change-cause="Upgrade nginx to 1.26" --overwrite
```

## What I learned

- A Deployment manages ReplicaSets, not Pods directly — every update creates a new ReplicaSet rather than mutating Pods in place, which is what enables clean rollback.
- Rolling updates are gradual by default: Kubernetes never drops below the configured minimum available replicas during an update, achieving zero-downtime deployments without any extra configuration.
- Old ReplicaSets are kept (scaled to 0) rather than deleted, which is what makes `kubectl rollout undo` instant — it's just scaling the old ReplicaSet back up and the current one down.
- `--record` is deprecated; `kubectl annotate ... kubernetes.io/change-cause` is the forward-compatible way to document *why* a rollout happened, which matters a lot for team environments and postmortems.

