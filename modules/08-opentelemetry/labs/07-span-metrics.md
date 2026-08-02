# Lab 08.07 — When two sources of truth disagree

**EXTEND · 45 min**

> Skip if behind schedule. Worth doing before module 11 — a canary gated on the
> wrong RED metric promotes the wrong thing.

## Context

The `spanmetrics` connector derives RED metrics from traces. You now have two
independent measurements of the same thing. They will not agree, and
understanding why is the lab.

## The problem

### Part 1 — derive RED from spans

```yaml
connectors:
  spanmetrics:
    dimensions:
      - name: http.route
      - name: http.response.status_code
    histogram:
      explicit:
        buckets: [10ms, 50ms, 100ms, 250ms, 500ms, 1s, 2s, 5s]

service:
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [memory_limiter, batch]
      exporters:  [otlp/tempo, spanmetrics]
    metrics/spanmetrics:
      receivers:  [spanmetrics]
      processors: [batch]
      exporters:  [prometheusremotewrite]
```

### Part 2 — compare

Build a Grafana panel with both, on the same axes:

```promql
# Direct, from module 07
sum(rate(pulse_http_requests_total[5m])) by (path)

# Derived from spans
sum(rate(traces_span_metrics_calls_total[5m])) by (http_route)
```

Record the discrepancy in request rate, error rate and p99.

### Part 3 — explain every difference

1. Request rate differs. How much, and why? (Start with your sampling
   configuration.)
2. Error rate differs, and the span-derived one is **higher**. Why does tail
   sampling bias it upward?
3. p99 differs. Two causes: bucket boundaries, and where the measurement is
   taken.
4. Some routes appear in one and not the other. Which, and why?

### Part 4 — the decision

5. Which do you use for your SLO, and why?
6. Which do you use for exploration and debugging?
7. Is there a configuration in which the span-derived metrics **are** safe for an
   SLO?

## Expected outcome

Both sources on one panel, every difference explained rather than hand-waved, and
an explicit decision about which drives the SLO.

## The answer that matters

**SLOs use directly instrumented metrics.** Span-derived metrics inherit your
sampling bias, and a sampled measurement is not a reliable denominator. If tail
sampling keeps 100% of errors and 1% of successes, the derived error rate is off
by two orders of magnitude — and an SLO built on it is worse than no SLO.

Span metrics are excellent for exploration, for dimensions you never added to
your direct metrics, and for services you have not instrumented directly. They
are not a measurement system of record.

Question 7's answer: only with 100% sampling before the connector, which is
sometimes affordable at the Collector when it is not at the backend.

## Why this lab exists

Module 11 gates a canary on an error rate. Choosing the biased source there means
rejecting good releases and promoting bad ones — and the failure looks like the
canary being flaky rather than the metric being wrong.
