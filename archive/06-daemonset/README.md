**Module:** 06 - DaemonSet
**Date:** 2026-07-09

## Objective
Deploy a DaemonSet to understand its "one Pod per node" guarantee, and confirm its behavioral differences from a Deployment/ReplicaSet: no manual scaling, and automatic Pod recreation tied to node count rather than a replica count.

## What I did

1. Created the DaemonSet manifest (`daemonset.yaml`):

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
  labels:
    app: node-monitor-demo
spec:
  selector:
    matchLabels:
      app: node-monitor-demo
  template:
    metadata:
      labels:
        app: node-monitor-demo
    spec:
      containers:
        - name: node-monitor
          image: nginx:1.26
          ports:
            - containerPort: 80
```

(Using nginx as a stand-in for a real node-level agent such as `node-exporter` or `fluentd`, to stay consistent with earlier labs.)

2. Applied it and verified:
```bash
kubectl apply -f daemonset.yaml
kubectl get daemonsets
kubectl get pods -o wide
```

Result: `DESIRED: 1 / CURRENT: 1`, matching the single-node Kind cluster (`k8s-portfolio-control-plane`). One Pod (`node-monitor-bsmq9`) was scheduled on that node.

3. Attempted to scale the DaemonSet manually:
```bash
kubectl scale daemonset node-monitor --replicas=3
```

4. Deleted the running DaemonSet Pod to test self-healing:
```bash
kubectl delete pod node-monitor-bsmq9
kubectl get pods -o wide
```

## Issue encountered

`kubectl scale daemonset node-monitor --replicas=3` failed:
Error from server (NotFound): the server could not find the requested resource

## Solution / Troubleshooting

This isn't an error to "fix" — it's expected behavior and confirms how DaemonSets work: they don't expose a `scale` subresource, because the number of Pods is determined by the number of matching nodes in the cluster, not by a replica count you set. To run more Pods, you'd add more nodes (or adjust a node selector/affinity rule), not scale the DaemonSet directly.

## Self-healing test

Deleted the running Pod (`node-monitor-bsmq9`):
NAME                  READY   STATUS    RESTARTS   AGE
node-monitor-vm4jn    1/1     Running   0          26s

A replacement Pod (`node-monitor-vm4jn`) was scheduled on the same node within 26 seconds — same self-healing principle as a ReplicaSet, but scoped to "exactly one Pod per eligible node" instead of a fixed replica count.

## What I learned

- DaemonSets guarantee **one Pod per node** (or per matching node, if a node selector is used) — the Pod count is a function of cluster topology, not a configurable replica number.
- Attempting `kubectl scale` on a DaemonSet fails with a clear `NotFound` error, since DaemonSets don't implement the `scale` subresource that Deployments and ReplicaSets do.
- To increase DaemonSet Pod count, the correct action is adding nodes to the cluster (or widening the node selector), not scaling the resource itself.
- Self-healing works the same way as with a ReplicaSet — a deleted Pod is replaced automatically — but the DaemonSet controller reconciles against node membership rather than a desired replica count.
- Typical real-world use cases: log collectors (Fluentd, Filebeat), node-level monitoring agents (Prometheus node-exporter), and networking components (kube-proxy, CNI plugins) — anything that needs exactly one instance running on every node.
