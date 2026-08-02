# Lab 08.02 — Instrument by hand

**CORE · 55 min**

## Context

Auto-instrumentation is the right answer in production and the wrong answer for
learning. You will write the spans yourself once, so that when auto-instrumentation
produces something strange you know what it was trying to do.

## The problem

### Part 1 — the provider

Wire up the SDK in `pulse-api`:

1. A `TracerProvider` with a `Resource` carrying `service.name`,
   `service.version` and `deployment.environment`.
2. An OTLP gRPC exporter pointing at the Collector (not yet deployed — point it
   at a stdout exporter for now).
3. A `BatchSpanProcessor` with explicit settings. Write down every default you
   are overriding and why.
4. Clean shutdown: `TracerProvider.Shutdown()` on `SIGTERM`, before the HTTP
   server finishes closing.

Point 4 matters more than it looks. Get the ordering wrong and you lose the spans
from every request that was in flight during a deploy — which, in a rolling
update, are precisely the interesting ones.

### Part 2 — spans that are worth having

Instrument the request path. For each span decide, deliberately:

- the **name** (low cardinality: `GET /api/checks`, never the full URL)
- the `SpanKind`
- attributes worth recording
- what counts as an error

```go
ctx, span := tracer.Start(r.Context(), "POST /api/checks",
    trace.WithSpanKind(trace.SpanKindServer),
    trace.WithAttributes(
        semconv.HTTPRequestMethodKey.String(r.Method),
        semconv.URLPath(r.URL.Path),
    ))
defer span.End()
```

Then add a child span around the store operation, so you can see how much of the
request is the handler and how much is storage.

### Part 3 — errors done properly

```go
if err != nil {
    span.RecordError(err)
    span.SetStatus(codes.Error, "could not persist check")
    // ...
}
```

Answer in `NOTAS.md`:

1. Difference between `RecordError` and `SetStatus`. Why do you usually want
   both?
2. A 404 — is that an error span? Argue it.
3. What does `RecordError` actually add to the span, and what is its cost during
   an incident when everything is failing? (This is the break-fix.)

### Part 4 — look at the output

With the stdout exporter, make one request and read the raw span JSON.

4. How large is one span, in bytes?
5. How much larger is a span with a recorded error and stack trace?
6. Multiply by your request rate. What volume of telemetry does Pulse produce per
   hour, in the healthy case? And during an incident?

**Write those numbers down.** They are what you need to size the Collector, and
the break-fix is a Collector that was sized for the first number.

## Expected outcome

`pulse-api` producing real spans, the six questions answered, and a measured
per-span size for both healthy and error cases.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

Usually not. A 404 is the server correctly telling the client the resource does
not exist — the system worked. Marking client errors as span errors makes your
error rate track user behaviour rather than your reliability, which is the same
mistake as the naive SLI in module 07. Convention: 5xx is an error span, 4xx is
not, unless you have a specific reason.
</details>

<details><summary>Hint 2 — part 1, point 4</summary>

`Shutdown()` flushes the batch processor. If the process exits first, everything
still in the batch queue is gone. Order: stop accepting new requests → drain
in-flight → flush the tracer → exit. Getting it backwards is invisible until you
go looking for the spans of a bad deploy and find nothing.
</details>
