# Lab 11.02 — Analysis driven by the SLO

**CORE · 50 min**

## Context

The gate. Everything in this module depends on this query being right, and this
module's break-fix is what happens when it is subtly wrong.

## The problem

### Part 1 — make the label available

Before writing any query, make sure you *can* scope one to the canary.

```bash
kubectl get pods -n pulse --show-labels | grep rollouts-pod-template-hash
curl -s localhost:9090/api/v1/query?query=pulse_http_requests_total | jq '.data.result[0].metric'
```

1. Does the metric carry `rollouts_pod_template_hash`? If not, why not?
2. Fix it. Which object needs changing, and what field?

Question 2 is the step everyone misses, and skipping it makes a correctly written
query return nothing — which fails in a way that looks like success.

### Part 2 — the AnalysisTemplate

Write one that measures error rate **for the canary only**:

```yaml
spec:
  args:
    - name: canary-hash
  metrics:
    - name: error-rate
      initialDelay: 2m
      interval: 60s
      count: 5
      successCondition: result[0] < 0.05
      failureLimit: 0
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(pulse_http_requests_total{
              status=~"5..",
              rollouts_pod_template_hash="{{args.canary-hash}}"
            }[2m]))
            /
            clamp_min(sum(rate(pulse_http_requests_total{
              rollouts_pod_template_hash="{{args.canary-hash}}"
            }[2m])), 1)
```

For each parameter, write down in `NOTAS.md` **why that value**:

| Parameter | Value | Why |
|---|---|---|
| `initialDelay` | | |
| `interval` | | |
| `count` | | |
| `successCondition` | | |
| `failureLimit` | | |

`successCondition` must be derived from the module 07 SLO, not chosen by feel.

### Part 3 — a second metric

Error rate alone misses a release that is correct and slow. Add latency:

```promql
histogram_quantile(0.99, sum by (le) (rate(
  pulse_http_request_duration_seconds_bucket{
    rollouts_pod_template_hash="{{args.canary-hash}}"
  }[2m])))
```

3. Should both metrics have to pass, or either fail to abort? What does Argo
   Rollouts do by default?
4. What third metric would you add for `pulse-worker`? (Module 07 answered this:
   the saturation signal.)

### Part 4 — verify it can say no

Do not wait for production to test the gate.

```bash
# Build an image that fails a specific route
docker build -t pulse-api:broken --build-arg FAIL_ROUTE=/api/checks ...
kubectl argo rollouts set image pulse-api pulse-api=pulse-api:broken -n pulse
kubectl argo rollouts get rollout pulse-api -n pulse --watch
```

5. Did it reject? At which step? What value did the analysis measure?
6. How much traffic hit the broken canary before rejection? Compute the blast
   radius in requests, not percentages.

## Expected outcome

An analysis scoped to the canary, every parameter justified, two metrics, and a
demonstrated rejection with the blast radius measured in requests.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

Pod labels do not become metric labels automatically. The `ServiceMonitor` needs
`podTargetLabels: [rollouts-pod-template-hash]`, and note the label is written
with dashes on the pod and underscores in Prometheus. A query filtering on a
label that does not exist returns an empty result — and empty is not the same as
zero.
</details>

<details><summary>Hint 2 — question 6</summary>

requests = rate × (initialDelay + measurements × interval) × canary weight. With
2m delay, one 60s measurement, 10% weight and 50 rps, that is roughly
50 × 180 × 0.1 = 900 requests. Comparing that against the 22-minute incident in
the break-fix is the whole argument for getting this right.
</details>
