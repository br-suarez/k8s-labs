# Lab 08.05 — Metric to trace, in one click

**CORE · 50 min**

## Context

This is the payoff for modules 07 and 08 together, and the answer to module 07's
cardinality problem: keep metrics cheap and aggregated, and get per-request
detail from the trace they link to.

## The problem

### Part 1 — Tempo

Deploy Grafana Tempo (`v3.0.2`, pinned) in monolithic mode with local storage —
you do not need object storage for this. Point the Collector's OTLP exporter at
it and confirm traces arrive.

Record its memory footprint against your cluster budget.

### Part 2 — emit exemplars

Exemplars require three things to line up, and if any is missing you get silence
rather than an error:

1. **SDK:** record an exemplar with the trace ID when observing the histogram.
   With the Prometheus client, `ObserveWithExemplar`.
2. **Prometheus:** exemplar storage is behind a feature flag —
   `--enable-feature=exemplar-storage`. In the Operator, `enableFeatures`.
3. **Scrape:** exemplars ride on the OpenMetrics exposition format, so the
   scrape has to negotiate it.

Verify at each stage rather than at the end:

```bash
# Are they in the exposition output?
curl -s -H 'Accept: application/openmetrics-text' localhost:8080/metrics | grep '#'

# Did Prometheus store them?
curl -s -G 'http://localhost:9090/api/v1/query_exemplars' \
  --data-urlencode 'query=pulse_http_request_duration_seconds_bucket' \
  --data-urlencode "start=$(date -d '10 min ago' +%s)" \
  --data-urlencode "end=$(date +%s)" | jq
```

### Part 3 — wire Grafana

Configure the Prometheus datasource with an exemplar link to the Tempo
datasource, mapping the `trace_id` label. Then:

1. Build a p99 latency panel.
2. Confirm exemplars render as points on it.
3. Click one. You should land on the trace.

### Part 4 — use it for real

Inject latency into a subset of requests:

```bash
kubectl set env deployment/pulse-api -n pulse INJECT_LATENCY_PATH=/api/results INJECT_LATENCY_MS=2000
```

Then, **starting from the graph and without writing a query**, answer:

4. Which endpoint is slow?
5. Where inside the request does the time go?
6. Is it every request or a subset?

Time yourself. Compare against how long the same investigation took in module 07
with metrics alone.

### Part 5 — the cardinality argument

Write in `NOTAS.md`:

7. What would it have cost in series to answer question 4 using a `path` label
   with 41,000 values? Show the arithmetic from module 07.
8. What did exemplars cost instead?
9. What can exemplars **not** tell you that a high-cardinality label could?

Question 9 keeps you honest: exemplars give you *an* example, not aggregate
statistics. You cannot compute "p99 for this specific URL" from an exemplar.

## Expected outcome

Working metric-to-trace navigation, an investigation done from the graph alone
and timed, and an honest account of the trade-off.

## Verification

```bash
./platform/scripts/verify.sh traces
```

## Staged hints

<details><summary>Hint 1 — no exemplars appear</summary>

Check the three requirements in order rather than guessing. The most common
cause is the scrape not requesting OpenMetrics: exemplars simply are not present
in the classic Prometheus text format, so the endpoint looks fine and the data
was never there.
</details>

<details><summary>Hint 2 — trace ID label format</summary>

The exemplar label must be exactly what the Grafana datasource is configured to
map, conventionally `trace_id`, with the raw hex trace ID and no `0x` prefix.
A mismatch produces exemplars that render but link nowhere.
</details>
