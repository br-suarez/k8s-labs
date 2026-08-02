# Lab 07: Quick CLI Commands

**Module:** 07 - CLI
**Date:** 2026-07-10

## Objective
Build a working reference of the `kubectl` commands used most often for day-to-day inspection, debugging, and quick edits — beyond `apply`/`get`/`describe` covered in earlier labs.

## What I did

### 1. Cluster-wide inspection
```bash
kubectl get all
kubectl get pods --show-labels
```
`get all` lists every core resource (Pods, Services, Deployments, ReplicaSets, DaemonSets) in the current namespace in one call — useful for a quick full-picture check. `--show-labels` surfaces the labels driving selector-based resources (Deployments, ReplicaSets, DaemonSets), which matters given the label-collision issue found in Lab 04.

### 2. Resource usage (`top`)
```bash
kubectl top nodes
kubectl top pods
```

### 3. Manual scaling
```bash
kubectl scale deployment nginx-deployment --replicas=5
kubectl get deployment nginx-deployment
```
Result:
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   5/5     5            5           111m
Confirmed via events:
ScalingReplicaSet   deployment/nginx-deployment   Scaled up replica set nginx-deployment-57c67cf74d to 5 from 3

### 4. Cluster events (chronological)
```bash
kubectl get events --sort-by='.lastTimestamp' | tail -10
```
Useful for a fast timeline of what the cluster's controllers have been doing — pod creation, image pulls, scaling actions — without digging through `describe` on each resource individually.

### 5. Context and cluster management
```bash
kubectl config get-contexts
kubectl config current-context
```
Output showed two configured contexts on this machine — `kind-k8s-portfolio` (active) and `microk8s` (from earlier exploration of the MicroK8s installation path) — confirming `kubectl` can manage multiple clusters and switch between them with `kubectl config use-context <name>`.

## Issue encountered

`kubectl top pods` initially failed:
error: Metrics API not available

## Solution / Troubleshooting

Kind does not ship with `metrics-server` by default, since it's a separate component that scrapes resource usage from the kubelet. Installed it manually:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

By default, `metrics-server` also fails on Kind because it validates the kubelet's TLS certificate, which Kind's local nodes don't have a valid cert for. Patched the deployment to skip that validation (acceptable for local/dev clusters, not recommended for production):

```bash
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

After ~45 seconds, `metrics-server` reached `Running`, and `kubectl top nodes` / `kubectl top pods` returned live CPU/memory data.

## What I learned

- `metrics-server` is not part of a base Kind (or vanilla kubeadm) cluster — it has to be installed separately, and needs `--kubelet-insecure-tls` specifically in local/dev environments like Kind due to self-signed kubelet certs.
- `kubectl get events --sort-by='.lastTimestamp'` is a fast way to get a chronological view of cluster activity without inspecting each resource individually — very useful for quick troubleshooting.
- `kubectl scale` is the imperative shortcut for changing replica count without editing/reapplying the YAML manifest — convenient for quick tests, but the manifest becomes out of sync with the live state unless it's updated to match afterward.
- `kubectl config get-contexts` / `use-context` is how a single `kubectl` installation manages multiple clusters (in this case, Kind and a previously explored MicroK8s setup) — critical in real SRE work where you're usually juggling dev, staging, and prod contexts.
