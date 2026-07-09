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

Unable to listen on port 8080: Listeners failed to create with the following errors:
[unable to create listener: Error listen tcp4 127.0.0.1:8080: bind: address already in use
unable to create listener: Error listen tcp6 [::1]:8080: bind: address already in use]
error: unable to listen on any of the requested ports: [{8080 80}]

## Solution / Troubleshooting

Port 8080 was already in use by another local process (unrelated to Kubernetes). Rather than killing an unknown process, used a different local port for the forward:

```bash
kubectl port-forward my-first-pod 8081:80
```

This resolved it immediately — confirmed nginx was reachable at `http://localhost:8081`.

## What I learned

- The core Pod lifecycle: manifest → `kubectl apply` → scheduled to a node → image pulled → container running → traffic reachable via `port-forward`.
- `kubectl get pods -o wide` adds useful columns (Pod IP, node) for quick multi-pod inspection without running `describe` on each one.
- Local port conflicts on `port-forward` are a host-machine issue, not a cluster issue — checking with `lsof -i :<port>` before assuming something is wrong with the Pod saves debugging time.
- Established a naming convention early (English names for anything portfolio-facing) to keep resources consistent across labs.
