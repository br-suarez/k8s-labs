# The four queries, and why each is written that way

Structured on **RED** for the request path (Rate, Errors, Duration) plus
**saturation** from USE for the resource side. Four queries answer "is this
service healthy and does it have room to breathe".

Target: `slo-demo` in namespace `slo-demo`, ~590 req/s of steady traffic.

---

## 1. Rate — throughput by status

```promql
sum by (status) (rate(http_requests_total{job="slo-demo", path="/api"}[1m]))
```

**`rate` not `irate`.** `irate` uses only the last two samples, which makes it
extremely spiky and — worse — it silently ignores everything else in the range.
It is for graphing fast-moving signals at high resolution, never for alerting.
`rate` fits a line across the whole window and extrapolates over counter resets.

**`[1m]` is not arbitrary.** A rate window must contain at least 4 scrape
intervals or the result is noisy and sometimes empty. Scrape interval here is
15s, so `[1m]` is the practical floor. Alerting windows should be longer still.

**`sum by (status)` and not bare `sum`.** Keeping `status` is what makes the
query answer "throughput *and* how it splits", instead of collapsing a 20% error
rate into a flat line that never moves.

---

## 2. Errors — the failure ratio

```promql
sum(rate(http_requests_total{job="slo-demo", path="/api", status=~"5.."}[5m]))
  /
sum(rate(http_requests_total{job="slo-demo", path="/api"}[5m]))
```

**`sum(rate(...))`, never `rate(sum(...))`.** `sum` first would add together
counters from different pods; when any pod restarts, its counter resets to zero
and the sum drops. `rate` cannot tell that apart from a real decrease, so the
result is garbage exactly when a pod is crash-looping. Always rate first,
aggregate second.

**Both windows must match.** `[5m]` on top and `[1m]` below compares different
time spans and produces a number that means nothing.

**4xx is not in the numerator.** A client sending a malformed request is not the
service failing. Counting 4xx makes a vulnerability scanner look like an outage.

---

## 3. Duration — p99 latency

```promql
histogram_quantile(
  0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket{job="slo-demo", path="/api"}[5m]))
)
```

**`sum by (le)` is mandatory and is the most common mistake in PromQL.**
`histogram_quantile` needs one series per bucket boundary. Without `by (le)` the
`le` label is aggregated away and the function has nothing to interpolate over —
it returns `NaN` or nonsense. With `sum by (le)` the buckets from every pod are
combined correctly into one cluster-wide histogram.

**Percentiles from histograms are interpolated estimates, not measurements.**
The accuracy is bounded by bucket boundaries: with edges at `0.2` and `0.3`, a
p99 that lands between them is a linear guess inside that gap. Widening buckets
degrades precision invisibly.

**Never average a percentile.** `avg(p99)` across pods is meaningless. Aggregate
the *buckets*, then compute the quantile — which is exactly what `sum by (le)`
does.

---

## 4. Saturation — how close to the limit

```promql
max by (pod) (
  container_memory_working_set_bytes{namespace="slo-demo", container="slo-demo"}
  /
  on (pod, container) kube_pod_container_resource_limits{namespace="slo-demo", container="slo-demo", resource="memory"}
)
```

**`working_set`, not `usage`.** `container_memory_usage_bytes` includes
reclaimable page cache, so it drifts up toward the limit on any workload that
touches files and looks alarming while nothing is wrong. `working_set` is what
the kernel actually considers when deciding to OOM-kill, which makes it the only
one worth alerting on.

**Utilisation is not saturation.** For CPU the honest saturation signal is not
usage but *throttling* — how much the process was made to wait:

```promql
sum by (pod) (rate(container_cpu_cfs_throttled_periods_total{namespace="slo-demo"}[5m]))
  /
sum by (pod) (rate(container_cpu_cfs_periods_total{namespace="slo-demo"}[5m]))
```

A container pinned at its CPU limit shows 100% utilisation and may be perfectly
fine. One being throttled 30% of its scheduling periods is being actively
starved, and that shows up as latency long before any CPU graph looks wrong.

**`on (pod, container)`** — the two metrics come from different exporters
(cAdvisor and kube-state-metrics) and carry different label sets. Without
telling PromQL which labels to join on, the division produces an empty vector.
