# Lab 08: Namespaces

**Module:** 08 - Namespaces
**Date:** 2026-07-11

## Objective
Create a custom Namespace and confirm resource isolation between namespaces — the same Deployment manifest deployed into a different namespace should not collide with, or appear alongside, resources in `default`.

## What I did

1. Inspected existing namespaces:
```bash
kubectl get namespaces
```
NAME                 STATUS   AGE
default              Active   2d20h
kube-node-lease      Active   2d20h
kube-public          Active   2d20h
kube-system          Active   2d20h
local-path-storage   Active   2d20h

2. Created a new namespace (`namespace.yaml`):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio-demo
```
```bash
kubectl apply -f namespace.yaml
```

3. Deployed the existing Module 05 Deployment manifest into the new namespace, without modifying the file itself:
```bash
kubectl apply -f ../05-deployments/deployment.yaml -n portfolio-demo
```

4. Verified isolation:
```bash
kubectl get pods -n portfolio-demo
kubectl get pods
```
Pods from `portfolio-demo` (`nginx-deployment-854d55664f-*`) did **not** appear in the default `kubectl get pods` output — confirming namespaces isolate resources by default, even when the Deployment name is identical.

5. Checked namespace-level resource governance:
```bash
kubectl describe namespace portfolio-demo
```
No resource quota.
No LimitRange resource.
Confirms namespaces have no resource restrictions by default — quotas and limits have to be explicitly defined (covered in Module 10).

## Issue encountered (unrelated to namespaces, but occurred during this session)

Before starting this lab, the Kind cluster was unresponsive after a VM restart:
Get "https://127.0.0.1:42619/api/v1/namespaces?limit=500": read tcp 127.0.0.1:37610->127.0.0.1:42619: read: connection reset by peer
`docker ps` showed the `k8s-portfolio-control-plane` container had just restarted (`Up 41 seconds`) — the control plane components (etcd, kube-apiserver, kubelet) were still initializing inside the container.

## Solution / Troubleshooting

Waited ~30 seconds for the control plane to finish starting up, then retried:
```bash
kubectl get nodes
kubectl get namespaces
```
Both returned normally once the control plane was fully up. Also verified the inotify limits set in Lab 01 had persisted correctly across the restart (`/etc/sysctl.conf` survived, no need to reapply).

As a side effect of the restart, existing Pods in `default` showed increased `RESTARTS` counts — expected, since Kubernetes restarted them as part of recovering cluster state.

## What I learned

- The exact same manifest (same Deployment name, same labels) can be applied to two different namespaces without any collision — namespaces provide full resource isolation by default.
- `kubectl get <resource>` without `-n` only queries the current namespace context (`default` in this case); resources in other namespaces are invisible unless explicitly queried with `-n <namespace>` or `--all-namespaces`.
- Namespaces have no built-in resource limits — a namespace with no `ResourceQuota`/`LimitRange` can consume as much of the cluster's resources as is available, which is a real production risk in multi-tenant clusters.
- After a host/VM restart, a Kind cluster's control plane needs a short warm-up window before `kubectl` commands succeed — worth checking `docker ps` (container uptime) before assuming something is broken.
