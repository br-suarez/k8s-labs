# Lab 07.06 — Blow it up on purpose

**EXTEND · 40 min**

> Do this **after** the break-fix. Diagnosing it cold is worth more; this lab is
> where you build the defences.

## Context

You are going to cause a cardinality explosion in a controlled setting, watch
Prometheus die, and then build the three layers that stop it.

## The problem

### Part 1 — measure the baseline

```bash
curl -s localhost:9090/api/v1/query?query=prometheus_tsdb_head_series | jq -r '.data.result[0].value[1]'
kubectl top pod -n monitoring prometheus-kube-prometheus-0
```

### Part 2 — explode it

Add a `url` label to the worker's probe histogram, then register a few thousand
checks:

```bash
for i in $(seq 3000); do
  curl -s -XPOST localhost:8080/api/checks \
    -d "{\"url\":\"http://pulse-web/path-$i\",\"interval_seconds\":300}" > /dev/null
done
```

Watch, every 30 seconds:

```bash
watch -n30 'curl -s localhost:9090/api/v1/query?query=prometheus_tsdb_head_series \
  | jq -r ".data.result[0].value[1]"; kubectl top pod -n monitoring | grep prometheus'
```

Record: series count over time, memory over time, and when queries start
degrading. Compute the predicted series count first and compare against observed.

### Part 3 — find the culprit with only Prometheus

Pretend you do not know the cause. Find it:

```bash
# Top metrics by series count
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[:10]'

# Highest-cardinality label values
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.labelValueCountByLabelName[:10]'

# Which labels consume most memory
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.memoryInBytesByLabelName[:10]'
```

`/status/tsdb` is the single most useful endpoint for this class of problem.
Learn it now.

### Part 4 — the three defences

**a) Server-side limits.** Set `enforcedSampleLimit` low enough to trip. Confirm
that the offending scrape fails while Prometheus stays healthy. Verify with
`up{job="pulse-worker"} == 0` and the `scrape_samples_scraped` metric.

**b) Relabelling.** Drop the label at ingestion, without changing the
application:

```yaml
metricRelabelings:
  - sourceLabels: [__name__]
    regex: 'pulse_probe_duration_seconds_bucket'
    targetLabel: url
    replacement: ''
    action: replace
```

Get it working, then explain the difference between `metricRelabelings` and
`relabelings` — they run at different stages and the distinction matters.

**c) An alert on growth:**

```promql
deriv(prometheus_tsdb_head_series[1h]) > 1000
```

Explain why the derivative is more useful here than an absolute threshold.

### Part 5 — recover

Remove the label, then deal with the series already ingested. They persist until
retention expires.

1. Do the old series still consume memory after you stop producing them?
2. What is `--storage.tsdb.max-block-duration` doing to your recovery time?
3. Is there a way to delete series without waiting for retention? Should you?

## Expected outcome

Predicted versus observed series counts, the culprit found via `/status/tsdb`
alone, all three defences working, and the recovery questions answered.

## Cleanup

```bash
kubectl delete pods -n pulse -l app=pulse-worker
# and remove the test checks
```

## Staged hints

<details><summary>Hint 1 — question 1</summary>

Yes. A series stays in the head block and the index until it ages out of
retention. Stopping the ingestion halts the growth but does not free the memory.
This is why the fix is never "remove the label and wait" during an incident —
you also have to get Prometheus to a state where it can start at all.
</details>

<details><summary>Hint 2 — the two relabelling stages</summary>

`relabelings` run **before** the scrape, against target metadata — they decide
what to scrape and how to label the target. `metricRelabelings` run **after**,
against each scraped sample — they can drop metrics or rewrite labels. To drop a
high-cardinality label you need the second. Using the first does nothing and
looks like it should work.
</details>
