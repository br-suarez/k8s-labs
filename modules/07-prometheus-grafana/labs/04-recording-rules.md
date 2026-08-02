# Lab 07.04 — Make a slow dashboard fast

**CORE · 50 min**

## Context

The module's exit criterion: take a panel from 8 seconds to under 1, and explain
why it worked. Both halves count — a speedup you cannot explain is one you cannot
reproduce.

## The problem

### Part 1 — build something genuinely slow

Generate enough data that this is real, not simulated:

```bash
# Register a few hundred checks so the worker produces real volume
for i in $(seq 300); do
  curl -s -XPOST localhost:8080/api/checks \
    -H 'content-type: application/json' \
    -d "{\"url\":\"http://pulse-web/$i\",\"interval_seconds\":5}" > /dev/null
done
```

Let it run and accumulate. Then build a Grafana panel over a long range with:

```promql
histogram_quantile(0.99,
  sum by (le, path, method, status)
  (rate(pulse_http_request_duration_seconds_bucket[5m])))
```

### Part 2 — measure, do not guess

```bash
time curl -s -G 'http://localhost:9090/api/v1/query_range' \
  --data-urlencode 'query=histogram_quantile(0.99, sum by (le, path) (rate(pulse_http_request_duration_seconds_bucket[5m])))' \
  --data-urlencode "start=$(date -d '30 days ago' +%s)" \
  --data-urlencode "end=$(date +%s)" \
  --data-urlencode 'step=300' -o /dev/null
```

Record: wall time, and from `prometheus_engine_query_duration_seconds` the
breakdown by phase. Also record how many series the query touches:

```bash
curl -s -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=count(pulse_http_request_duration_seconds_bucket)' | jq -r '.data.result[0].value[1]'
```

**Write these numbers down.** They are the "before" in your README.

### Part 3 — the recording rule

Write a `PrometheusRule` that precomputes it. The critical design decision is the
`by` clause.

```yaml
- record: pulse:http_request_duration_seconds:rate5m
  expr: sum by (le, path) (rate(pulse_http_request_duration_seconds_bucket[5m]))
```

Note what is **missing** from that `by`: `method` and `status`. Dropping
dimensions is what makes it fast. Decide which you can afford to lose and record
the reasoning — this is the judgement call, not the syntax.

Then measure again, same method.

### Part 4 — explain the mechanism

In `NOTAS.md`, answer precisely:

1. Where did the time go before? Which phase of query execution dominated?
2. What exactly does the rule precompute, and at what interval?
3. Why can you not just record `histogram_quantile(...)` directly? Try it and see
   what breaks.
4. What is the cardinality of the recorded series? Show the arithmetic.
5. What did you give up? Can you still answer "p99 by status code"?
6. How much extra storage does the rule cost per day?

### Part 5 — the counter-example

Now write a rule that does **not** help:

```yaml
- record: pulse:everything
  expr: sum by (le, path, method, status, instance, pod) (rate(...))
```

Measure it. Explain why it is slower and more expensive than no rule at all.
This is the shape of the mistake in this module's break-fix.

## Expected outcome

Before/after timings on the same query, both under the same method, and question
3 answered from having tried it.

## Verification

```bash
./platform/scripts/verify.sh slo
```

## Staged hints

<details><summary>Hint 1 — question 3</summary>

`histogram_quantile` must be applied at query time to the aggregated buckets. If
you record the quantile itself you have thrown away the buckets, and quantiles
are not aggregatable — you cannot average p99s across instances and get a
meaningful p99. Record the aggregated **buckets**; apply the quantile at query
time. This trips up almost everyone once.
</details>

<details><summary>Hint 2 — question 1</summary>

`prometheus_engine_query_duration_seconds` splits by `slice`: `queryPreparation`,
`innerEval`, `results`. A high `innerEval` on a `rate()` over many series means
you are reading and computing over too much raw data — exactly what a recording
rule fixes by doing it once per interval instead of once per dashboard refresh
per viewer.
</details>
