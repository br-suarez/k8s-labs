# Lab 03: First Steps — Building a Pod

**Module:** 03 - First Steps
**Date:** 2026-07-09

## Objective
Create, inspect, and access the first Kubernetes Pod running an nginx container, covering the core `kubectl` workflow: apply, get, describe, and port-forward.

## What I did

1. Created the Pod manifest (`pod.yaml`):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
  labels:
    app: nginx-demo
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
```

2. Applied it to the cluster:
```bash
kubectl apply -f pod.yaml
```

3. Verified status:
```bash
kubectl get pods
kubectl get pods -o wide
kubectl describe pod my-first-pod
```

4. Cleaned up an earlier test Pod created before establishing naming conventions:
```bash
kubectl delete pod mi-primer-pod
```

5. Exposed the Pod locally to confirm nginx was serving traffic:
```bash
kubectl port-forward my-first-pod 8081:80
```
Then verified in the browser at `http://localhost:8081` — nginx default page loaded successfully.

## Issue encountered

`kubectl port-forward my-first-pod 8080:80` failed:
