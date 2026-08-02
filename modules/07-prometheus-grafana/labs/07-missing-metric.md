# Lab 07.07 — The metric that disappeared

**EXTEND · 35 min**

> Skip if behind schedule. The diagnostic path here is used again in module 08
> when spans go missing.

## Context

A dashboard panel that worked last week is empty. The application is running and
the code has not changed. Four layers can be responsible, and each fails
differently.

## The problem

Reproduce each failure, then diagnose it **from the empty panel alone** — no
peeking at what you broke.

### Failure A — the ServiceMonitor selects nothing

Change the `ServiceMonitor`'s `selector.matchLabels` so it matches no Service.

### Failure B — the port name does not match

Rename the port in the Service but not in the `ServiceMonitor`'s
`endpoints[].port`.

### Failure C — namespace selector excludes the target

Set `namespaceSelector.matchNames` to a namespace that does not contain the
Service.

### Failure D — the metric is dropped by relabelling

Add a `metricRelabelings` rule that drops the metric after a successful scrape.

## The diagnostic ladder

For each, walk down until you find where it breaks, and record which rung
identified it:

```bash
# 1. Is the target known to Prometheus at all?
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, lastError, scrapeUrl}'

# 2. Did the Operator generate config for it?
kubectl get secret prometheus-kube-prometheus-prometheus -n monitoring \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip | grep -A20 pulse

# 3. Does the endpoint serve the metric?
kubectl exec -n pulse deploy/pulse-api -- wget -qO- localhost:8080/metrics | grep pulse_http

# 4. Does the Service have endpoints?
kubectl get endpointslice -n pulse

# 5. Was it scraped but dropped?
curl -s localhost:9090/api/v1/query?query=scrape_samples_scraped | jq
```

Failure D is the interesting one: the target is `up`, the scrape succeeds,
`scrape_samples_scraped` is non-zero, and the metric still is not there. Which
rung catches it?

## The deliverable

A decision tree in `NOTAS.md`:

```
Metric missing from Prometheus
├─ target absent from /api/v1/targets   → selector or namespaceSelector
├─ target present, health=down          → network, port name, or auth
├─ target up, samples_scraped = 0       → endpoint serves nothing at that path
├─ samples_scraped > 0, metric absent   → metricRelabelings dropped it
└─ metric present, panel empty          → the query, the time range, or the label set
```

Expand each branch with the confirming command. That last branch is the one
people forget: sometimes the metric is fine and the dashboard is wrong.

## Expected outcome

Four failures reproduced and diagnosed blind, and a decision tree you would
actually use on call.

## Why this lab exists

Missing telemetry is worse than wrong telemetry, because it looks like "nothing
is happening". Being able to walk this ladder in two minutes rather than twenty
is the difference on a real incident — and module 08 has the same problem with
spans.
