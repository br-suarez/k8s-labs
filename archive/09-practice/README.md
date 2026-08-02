# Lab 09: Practice — Combining Namespaces, Deployments, and Resource Management

**Module:** 09 - Practice
**Date:** 2026-07-11

## Objective
Combine concepts from Modules 03–08 into a more realistic scenario: a dedicated namespace, a Deployment with well-scoped labels and resource requests/limits, verified through the CLI toolkit from Module 07, plus a scaling exercise observed through cluster events.

## What I did

1. Created a dedicated namespace (`namespace.yaml`):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: practice-app
```

2. Created a Deployment with explicit, non-colliding labels and resource requests/limits (`deployment.yaml`):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: practice-web
  namespace: practice-app
  labels:
    app: practice-web
    tier: frontend
spec:
  replicas: 4
  selector:
    matchLabels:
      app: practice-web
  template:
    metadata:
      labels:
        app: practice-web
        tier: frontend
    spec:
      containers:
        - name: nginx
          image: nginx:1.26
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
```

3. Applied both and verified with the CLI toolkit from Module 07:
```bash
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl get all -n practice-app
kubectl get pods -n practice-app --show-labels
kubectl top pods -n practice-app
```
Result: 4/4 Pods running, correct `app`/`tier` labels, no collision with resources in other namespaces.

4. Scaling test:
```bash
kubectl scale deployment practice-web -n practice-app --replicas=6
kubectl get pods -n practice-app
kubectl scale deployment practice-web -n practice-app --replicas=4
kubectl get pods -n practice-app
kubectl get events -n practice-app --sort-by='.lastTimestamp' | tail -15
```
Events confirmed the full lifecycle for both new Pods created during scale-up and terminated during scale-down:
SuccessfulCreate   replicaset/practice-web-79d885bfbc   Created pod: practice-web-79d885bfbc-f7mvl
Scheduled          pod/practice-web-79d885bfbc-f7mvl    Successfully assigned practice-app/...
Pulled             pod/practice-web-79d885bfbc-f7mvl    Container image "nginx:1.26" already present on machine
Created            pod/practice-web-79d885bfbc-f7mvl    Created container nginx
Started            pod/practice-web-79d885bfbc-f7mvl    Started container nginx
Killing            pod/practice-web-79d885bfbc-f7mvl    Stopping container nginx
SuccessfulDelete   replicaset/practice-web-79d885bfbc   Deleted pod: practice-web-79d885bfbc-f7mvl
ScalingReplicaSet  deployment/practice-web              Scaled down replica set practice-web-79d885bfbc to 4 from 6

## Issue encountered

Noticed the cluster felt slower than usual mid-session. Investigated cluster-wide resource usage:
```bash
kubectl get pods --all-namespaces
kubectl top nodes
kubectl top pods --all-namespaces
docker stats --no-stream
```

`kubectl top nodes` showed only 22% CPU / 16% memory in use — no actual resource shortage. However, `kube-system` components showed unusually high `RESTARTS` counts:
kube-controller-manager   54 restarts
kube-scheduler            54 restarts
kube-apiserver             6 restarts
etcd                       5 restarts
metrics-server            28 restarts
`docker stats` confirmed elevated host CPU usage (282%) on the Kind container despite idle workloads — consistent with control plane components repeatedly recovering/restarting rather than genuine application load.

## Solution / Troubleshooting

Root cause: the host VM had been restarted multiple times over the course of the exercises. Each VM restart forces the entire single-node control plane (etcd, kube-apiserver, kube-controller-manager, kube-scheduler) to recover inside the same container, which shows up as accumulated restart counts and transient CPU spikes — not a resource capacity problem.

Cleaned up an unused namespace left over from Module 08 to reduce unnecessary load:
```bash
kubectl delete namespace portfolio-demo
kubectl get namespaces
kubectl get pods --all-namespaces
```
Restart counters stopped increasing once VM restarts stopped, confirming the diagnosis.

## What I learned

- Low `kubectl top nodes` percentages don't guarantee a healthy cluster — high `RESTARTS` counts on `kube-system` control plane Pods are a better early signal of instability than raw CPU/memory usage.
- A single-node Kind cluster's control plane (etcd, apiserver, scheduler, controller-manager) has to fully recover after every host/VM restart, unlike a real multi-node production cluster where control plane HA prevents a single host restart from affecting cluster availability.
- `docker stats` gives a host-level view that can reveal transient load (recovery, crash-looping) that `kubectl top` — which only reflects steady-state usage — won't necessarily show as clearly.
- Explicit `resources.requests`/`limits` on containers (used here for the first time) is a baseline best practice: it prevents a single Pod from starving others of CPU/memory on a shared node, and enables the scheduler to make better placement decisions.
- Scaling a Deployment up and back down cleanly reuses the same ReplicaSet (no new ReplicaSet is created for a scale operation — only image/spec changes trigger that), which is visible directly in `kubectl get events`.
