# Lab 07.02 — Replace the hand-rolled exporter

**CORE · 45 min**

## Context

Since module 01, Pulse has emitted metrics from a hand-written text-format
exporter. Now you swap in the official client and compare the output line by
line. Having written it by hand first means you know exactly what the library is
doing for you.

## The problem

### Part 1 — diff your own work

Capture the current output:

```bash
curl -s localhost:8080/metrics > /tmp/handrolled.txt
```

Replace the `metrics` struct in `pulse-api` with
`github.com/prometheus/client_golang`. Keep the metric names identical.

```bash
curl -s localhost:8080/metrics > /tmp/official.txt
diff /tmp/handrolled.txt /tmp/official.txt
```

Answer in `NOTAS.md`:

1. What metrics appeared that you did not write? Where do they come from?
2. Did your hand-rolled histogram buckets match `DefBuckets`? Which is right for
   Pulse?
3. Your version was not concurrency-safe in one specific way. Find it. (Look at
   how `observe` mutates the map versus how `render` reads it.)
4. What does the client library do about counter resets that you did not?

### Part 2 — the buckets question

`DefBuckets` is `.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10` — 11 explicit buckets,
plus `+Inf` added automatically, so 12 `_bucket` series plus `_sum` and `_count`.

Measure Pulse's actual latency distribution, then choose buckets around **your
SLO threshold**, not around the default scale.

5. If your SLO is "99% of requests under 300 ms", which of the default buckets
   are useless to you? Which ones are missing?
6. What is the cardinality cost of adding four buckets?

### Part 3 — instrument the worker properly

`pulse-worker` needs its queue depth as a real gauge, plus:

- probe duration as a histogram, labelled by `result` **only** — not by `url`
- queue depth as a gauge
- dropped jobs as a counter

Before you add any label, write down its maximum distinct value count. If you
cannot, it is not a label.

### Part 4 — wire up scraping

Write a `ServiceMonitor` for each service. Then confirm end to end:

```bash
kubectl get --raw '/api/v1/query?query=up{job=~"pulse.*"}' | jq
```

## Expected outcome

Both services on the official client, the six questions answered, buckets chosen
against the SLO, and both targets `up` in Prometheus.

## Staged hints

<details><summary>Hint 1 — question 3</summary>

`observe` takes the mutex and writes; `render` takes the mutex and reads. That
part is fine. The bug is subtler: the histogram bucket counts are cumulative and
incremented in a loop, while `count` and `sum` are updated separately — a reader
arriving between those updates sees an inconsistent snapshot where the buckets
and the count disagree. The client library updates them atomically.
</details>

<details><summary>Hint 2 — question 1</summary>

`go_*` and `process_*`: goroutine counts, GC pause durations, heap size, open
file descriptors, CPU. They come free with the default registry and are
genuinely useful — a `go_goroutines` that climbs without bound is a goroutine
leak, and you will not see it any other way.
</details>
