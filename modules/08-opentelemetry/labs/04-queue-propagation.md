# Lab 08.04 — Across the queue

**CORE · 60 min.** The lab this module exists for.

## Context

Context propagates over HTTP almost for free — the instrumentation library
injects and extracts headers and you never think about it. Through a **queue** it
does not, and that is where most real distributed tracing stops being useful.

Almost every tutorial skips this, because their example is one service.

## The problem

### Part 1 — see it break

Instrument `pulse-worker` the way you instrumented the API in lab 02. Trigger a
probe end to end and look at the result in your backend.

You will have **two** unrelated traces:

```
Trace A: POST /api/checks → enqueue          (pulse-api)
Trace B: dequeue → probe → report            (pulse-worker)   ← orphan
```

Confirm it: the worker's root span has no parent, and its trace ID differs from
the API's. Record both trace IDs in `NOTAS.md` as evidence.

### Part 2 — why it happens

Answer before fixing anything:

1. Where exactly is the context lost? Name the line.
2. Why does HTTP not have this problem?
3. The worker picks up the job 40 seconds later. What does that imply about the
   parent span's lifetime?
4. Is the correct relationship parent-child, or a link? Argue it — this is the
   real question and it has a defensible answer either way.

### Part 3 — carry the context

Inject on the producer side:

```go
// Serialise the current context into the job payload
carrier := propagation.MapCarrier{}
otel.GetTextMapPropagator().Inject(ctx, carrier)

job := Job{
    CheckID:   c.ID,
    URL:       c.URL,
    TraceCtx:  carrier,        // travels with the job
}
```

Extract on the consumer side:

```go
ctx := otel.GetTextMapPropagator().Extract(context.Background(),
    propagation.MapCarrier(job.TraceCtx))

ctx, span := tracer.Start(ctx, "probe "+job.CheckID,
    trace.WithSpanKind(trace.SpanKindConsumer))
```

Verify a single connected trace across both services.

### Part 4 — parent or link?

Now implement the alternative and compare them side by side.

```go
// As a link rather than a parent
ctx, span := tracer.Start(context.Background(), "probe "+job.CheckID,
    trace.WithSpanKind(trace.SpanKindConsumer),
    trace.WithLinks(trace.Link{SpanContext: producerSpanCtx}))
```

Compare in your backend:

| | Parent-child | Link |
|---|---|---|
| How the trace renders | | |
| Total trace duration reported | | |
| Effect of the 40s delay on the waterfall | | |
| What happens if the producer trace was not sampled | | |

5. Which would you ship for Pulse? Defend it.

The strongest argument concerns duration: with parent-child, a job that sits in
the queue for 40 seconds produces a trace whose duration is 40 seconds, and every
latency view derived from traces becomes meaningless. With links, the producer
and consumer are separate traces that reference each other.

### Part 5 — the sampling trap

6. The producer's trace was not sampled. What happens to the worker's span with
   the parent-child approach? With links?
7. How would you guarantee that a probe which **fails** is always traced, even
   when its producer was not sampled?

Question 7 is the bridge into lab 06.

## Expected outcome

A single connected trace across the queue, both relationships implemented and
compared in a filled-in table, and a defended choice.

## Verification

```bash
# One trace ID, spans from both services
curl -s "http://tempo:3200/api/traces/<trace-id>" \
  | jq '[.batches[].resource.attributes[] | select(.key=="service.name") | .value.stringValue] | unique'
# ["pulse-api","pulse-worker"]
```

## Staged hints

<details><summary>Hint 1 — question 1</summary>

`w.enqueue(chk)` in the worker, and the corresponding write in the API. The `Job`
struct has no field for trace context, so when the goroutine picks it up it calls
`tracer.Start` with a background context. Nothing errors — a root span is a
perfectly valid thing to create, so the failure is silent.
</details>

<details><summary>Hint 2 — question 6</summary>

With parent-child, the sampling decision is inherited through `traceparent`'s
sampled flag: an unsampled parent means the child is unsampled too, so a failing
probe can be invisible. With links, the consumer makes its own decision. That
alone is a strong argument for links in a queue-based system — and it is what
makes "always trace failures" achievable.
</details>

## Why this lab exists

It is the difference between three disconnected traces and one story. It is also
the single most common gap in real-world tracing setups: HTTP is instrumented,
the async boundary is not, and nobody notices because each half looks fine.
