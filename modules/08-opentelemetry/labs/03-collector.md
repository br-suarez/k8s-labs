# Lab 08.03 — The Collector pipeline

**CORE · 50 min**

## Context

The Collector is where most OTel operational problems live. This lab builds one
that does real work, and instruments it so you can see what it is doing.

## The problem

### Part 1 — deploy it

Deploy the OTel Collector (`v0.157.0`, pinned) as a DaemonSet. Justify DaemonSet
over sidecar and over Deployment in `NOTAS.md` before you build it.

Minimum pipeline: `otlp` receiver → `memory_limiter`, `batch` → `debug`
exporter.

**`memory_limiter` goes first.** You will find out why in the break-fix; put it
in the right place now.

### Part 2 — processors that do real work

Add, in a deliberate order:

1. `k8sattributes` — enrich spans with pod, namespace, node, deployment. Note
   what RBAC it needs and why.
2. `resourcedetection` — cluster and node metadata.
3. `attributes` — redact anything sensitive. Pulse probes customer URLs, which
   may contain tokens in query strings. Write a rule that strips them.
4. `filter` — drop spans you do not want, health-check requests being the classic
   case.

Point 3 is not hypothetical: `https://api.example.com/data?token=abc123` in a
span attribute is a credential in your telemetry backend, readable by everyone
with Grafana access.

### Part 3 — observe the Collector

The Collector emits its own metrics on `:8888`. Scrape them with a
`ServiceMonitor` from module 07 and build a dashboard with:

| Metric | Why |
|---|---|
| `otelcol_receiver_accepted_spans` | Volume in |
| `otelcol_receiver_refused_spans` | Rejected at the door |
| `otelcol_processor_dropped_spans` | Dropped in the pipeline |
| `otelcol_exporter_sent_spans` | Volume out |
| `otelcol_exporter_send_failed_spans` | Backend problems |
| `otelcol_exporter_queue_size` / `_capacity` | Headroom |

**Accepted minus sent, over time, is data you lost.** Put that on the dashboard
as its own panel. It is the panel that would have caught this module's break-fix
while it was happening.

### Part 4 — break it deliberately

1. Point the exporter at a non-existent backend. What happens to the queue? How
   long until data is lost? Which metric shows it first?
2. Set `memory_limiter` absurdly low. Watch `refused_spans`. Where does the
   backpressure surface — in the Collector, or in the application?
3. Kill the Collector while spans are in flight. How many were lost? Now enable
   `file_storage` on the sending queue and repeat.

## Expected outcome

A Collector doing enrichment and redaction, its own metrics on a dashboard with
an explicit data-loss panel, and three break experiments recorded.

## Verification

```bash
kubectl logs -n monitoring ds/otel-collector | head -20
curl -s localhost:8888/metrics | grep otelcol_receiver_accepted_spans
```

## Staged hints

<details><summary>Hint 1 — k8sattributes RBAC</summary>

It needs `get`, `list` and `watch` on pods, namespaces and replicasets to map a
source IP to a pod and up to its owning Deployment. Without the replicaset
permission you get pod names but no deployment name, which is a confusing partial
failure — everything works, one attribute is quietly missing.
</details>

<details><summary>Hint 2 — question 2</summary>

Backpressure propagates to the SDK's `BatchSpanProcessor`, whose own queue then
fills, and it drops spans and increments its own dropped counter. The loss moves
from the Collector to the application — which is why you need the SDK's internal
metrics too, not only the Collector's.
</details>
