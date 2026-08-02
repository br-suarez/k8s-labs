# Refresher 29: PromQL & Alerting

**Module:** 29 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

Four queries run against live Prometheus, two classic PromQL mistakes shown
next to their correct form, and an alert forced to fire and then clear.

```bash
./run-lab.sh
```

Query reasoning: [`queries.md`](./queries.md).
Evidence: [`01-queries-and-alert.txt`](./evidence/01-queries-and-alert.txt).

---

## The four queries — RED plus saturation

Against `slo-demo` at ~590 req/s:

| Signal | Result |
|--------|--------|
| **Rate** — `sum by (status) (rate(...[1m]))` | `status=200 → 591.7/s`, `status=500 → 0.474/s` |
| **Errors** — `sum(rate(5xx)) / sum(rate(all))` | `0.108%` |
| **Duration** — `histogram_quantile(0.99, sum by (le) (rate(...)))` | p50 `85.3ms`, p90 `175.1ms`, p99 `198.6ms` |
| **Saturation** — `working_set / limit` | `21.5%`, `24.4%`, `25.1%` per pod |

Full reasoning for each in [`queries.md`](./queries.md) — why `rate` not `irate`,
why `working_set` not `usage`, why `on (pod, container)` is required to join
cAdvisor metrics against kube-state-metrics.

### The saturation query that returned nothing

```
--- CPU throttled periods ratio
  (empty result)
```

Not zero — **empty**. `slo-demo` sets a memory limit but no CPU limit, so there
is no CFS quota, so `container_cpu_cfs_throttled_periods_total` does not exist
for those containers.

An empty result and a healthy zero look identical on a dashboard panel and in a
`< 0.25` alert threshold. A missing series never breaches a threshold, so an
alert on a metric that does not exist is permanently green. This is why
`absent()` exists, and why "the alert never fired" is not evidence of health.

---

## Mistake 1 — `histogram_quantile` without `by (le)`

```
correct: histogram_quantile(0.99, sum by (le) (rate(..._bucket[5m])))
  => 198.61ms

wrong:   histogram_quantile(0.99, sum(rate(..._bucket[5m])))
  => (empty result)
```

`histogram_quantile` interpolates across bucket boundaries and needs one series
per `le` value. A bare `sum` aggregates `le` away, leaving the function nothing
to work with. This one fails loudly, which makes it the harmless mistake.

---

## Mistake 2 — `rate(sum(...))` instead of `sum(rate(...))`

```
correct: sum(rate(http_requests_total{...}[5m]))
  => 584.015

wrong:   rate(sum(http_requests_total{...})[5m:15s])
  => 589.232
```

**This is the dangerous one, and the numbers show exactly why: they agree.**
A 1% difference, no error, nothing to notice in review.

It stays plausible for as long as every pod stays up. `sum` first adds raw
counters across pods; when one pod restarts its counter resets to zero, the sum
drops, and `rate` cannot distinguish that from a genuine decrease. `rate` per
series handles resets correctly — but only if it runs *before* the aggregation.

The query breaks precisely when a pod is crash-looping, which is precisely when
someone is looking at it. **Always rate first, aggregate second.**

---

## Forcing the alert

The rule ([`alerts.yaml`](./alerts.yaml)) is a symptom alert, distinct in shape
from module 20's burn-rate alerts — those ask "how fast is the budget being
spent", this asks "are requests slow right now". Both are legitimate; they are
read at different moments.

```yaml
expr: job:http_request_duration_seconds:p99{service="slo-demo"} > 0.3
for: 2m
```

`0.3` is not a round number chosen for looking sensible — it is the latency
objective from [module 20's SLO spec](../20-slo-error-budgets/slo/slo-definition.md).

Injected `slow_rate=0.60` (60% of requests take 320–700ms):

| Time | p99 | Alert |
|------|-----|-------|
| 06:18:48 | 198.6ms | inactive |
| 06:19:19 | 555.2ms | inactive |
| **06:19:51** | 778.2ms | **pending** |
| 06:20:54 | 905.1ms | pending |
| **06:21:57** | 950.3ms | **firing** |

`pending → firing` took 2m 06s: the configured `for: 2m` plus one evaluation
interval. That delay is the alert refusing to page on a transient spike.

### Recovery

Restored `slow_rate=0.005`:

| Time | p99 |
|------|-----|
| 06:22:29 | 951.4ms |
| 06:24:35 | 915.3ms |
| 06:25:38 | 808.4ms |
| 06:26:09 | 642.1ms |
| 06:26:40 | 374.3ms |
| **06:27:11** | **198.7ms** → inactive |

The decay is the 5m rate window draining, not the service recovering slowly —
the service was healthy from the moment the injection stopped. p99 took **~5
minutes** to fall back below the threshold because the query averages over the
last 5 minutes by construction.

---

## What I re-learned

- **An empty result is not a zero, and no alerting rule can tell them apart.**
  The CPU throttling query returned nothing because those containers have no CPU
  limit. `< 0.25` on a non-existent series is never true, so that alert would sit
  green forever and look exactly like a healthy service. Alerting on a metric
  requires knowing the metric exists — which is what `absent()` is for.

- **The dangerous PromQL mistake is the one that returns a plausible number.**
  `sum by (le)` fails visibly with an empty result. `rate(sum(...))` returned
  589.2 against a correct 584.0 — indistinguishable in review, and wrong in
  exactly the situation where you are staring at the graph during an incident.

- **A rate window is a floor on how fast an alert can clear.** p99 stayed above
  300ms for five minutes after the service was already healthy, because the 5m
  window still contained the slow requests. Same mechanic as module 20's long
  burn-rate window — and the reason a resolved incident keeps paging if the
  window is the only condition.

- **`for:` is the tuning knob between noise and lag, and it is measurable.**
  2m 06s from pending to firing. Shorter means faster paging and more false
  positives; longer means the opposite. Writing it down as a number makes it a
  decision rather than a default.

- **Percentiles from histograms are estimates bounded by bucket edges.**
  A p99 of 198.6ms is interpolated inside whatever bucket it lands in. The
  histogram in module 20 has `0.3` as an exact boundary specifically so the SLI
  is a bucket ratio rather than an interpolation — a design decision made in
  application code long before anyone writes the query.
