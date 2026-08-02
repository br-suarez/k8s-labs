# Lab 07.01 — The stack, on a small cluster

**CORE · 45 min**

## Context

`kube-prometheus-stack` assumes a cluster with room. Yours does not have room.
Every value you reduce costs you something, and knowing what it costs is the
lab.

## The problem

### Part 1 — check what you are installing

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community/kube-prometheus-stack --versions | head -5
```

Pin the chart version you choose and record it in `SETUP.md`. Do not use
whatever `latest` resolves to today — the whole repo is pinned for a reason.

### Part 2 — install it deliberately

Write a `values.yaml`. For **every** value you set, record what it costs:

| Value | Set to | What it costs |
|---|---|---|
| `prometheus.prometheusSpec.retention` | | |
| `prometheus.prometheusSpec.resources.limits.memory` | | |
| `prometheus.prometheusSpec.scrapeInterval` | | |
| `grafana.persistence.enabled` | | |
| `alertmanager.alertmanagerSpec.retention` | | |
| Components disabled | | |

On the `lite` profile, start from: retention 6h, memory limit 1Gi, scrape
interval 60s, Grafana persistence off. Then measure whether you can afford more.

Critically, set the guardrails **now**, before you need them:

```yaml
prometheus:
  prometheusSpec:
    enforcedSampleLimit: 50000
    enforcedLabelLimit: 30
```

This module's break-fix is what happens without them.

### Part 3 — what did it actually deploy?

```bash
kubectl get all -n monitoring
kubectl get crd | grep monitoring.coreos.com
kubectl get servicemonitor,podmonitor,prometheusrule -A
```

Answer in `NOTAS.md`:

1. What does the Prometheus **Operator** do that plain Prometheus does not?
2. Where does the actual `prometheus.yml` live? Try to edit it directly and see
   what happens.
3. What is `node-exporter` doing as a DaemonSet, and what does it give you that
   kube-state-metrics does not?
4. How much memory is the whole stack using? Compare against your cluster
   profile's headroom.

### Part 4 — measure the floor

```bash
kubectl top pods -n monitoring
kubectl get --raw /api/v1/query?query=prometheus_tsdb_head_series | jq -r '.data.result[0].value[1]'
```

Record baseline series count and memory. You need both numbers as a reference
point — the break-fix is diagnosed by how far they move.

## Expected outcome

Working stack inside your memory budget, the cost table filled in, and a recorded
baseline.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

You cannot usefully edit it: the Operator generates it from `Prometheus`,
`ServiceMonitor` and `PrometheusRule` objects and overwrites your changes. It
lives in a Secret, gzipped. That indirection is the Operator's whole point —
configuration becomes Kubernetes objects with RBAC and validation instead of a
file someone edits by hand.
</details>

<details><summary>Hint 2 — if it will not fit</summary>

Disable what you are not using: `kubeApiServer`, `kubeControllerManager`,
`kubeScheduler`, `kubeProxy`, `kubeEtcd` scrape targets are informative but not
needed for this track's labs. Turning them off is a legitimate saving — record it
so you know what you gave up.
</details>
