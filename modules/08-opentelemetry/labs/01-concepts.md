# Lab 08.01 — Against the specification

**CORE · 40 min**

## Context

OpenTelemetry has more conceptual surface than most tools, and skipping it
produces people who can configure a Collector but cannot debug one. This lab is
reading — but active reading, with a deliverable.

## The problem

Read the specification, not a blog post. Then answer, in `NOTAS.md`, in your own
words:

### Signals and the model

1. What is a `Span`? List its required fields. What makes a span a **root** span?
2. `SpanKind` has five values. Name them and give a Pulse example of each.
3. What is a `SpanLink` and when do you use one **instead of** a parent
   relationship? (This one matters in lab 04.)
4. What is `Resource` and why is it attached at the provider level rather than
   per span?
5. Difference between an `Attribute`, a `SpanEvent` and `Baggage`. When would you
   reach for baggage, and what is its danger?

### Context

6. Write the `traceparent` header from memory, naming each field and its byte
   length.
7. What does the `sampled` flag do, and who sets it?
8. What is a `Propagator`? What happens if two services use different ones?

### The pipeline

9. Draw the path of a span from `tracer.Start()` to storage. Name every buffer it
   sits in. (You will need this in the break-fix.)
10. What is the `BatchSpanProcessor` and what does it do when its queue is full?

## The deliverable

A diagram in `NOTAS.md` of the whole path:

```
app code → SDK tracer → span processor → exporter → Collector receiver
  → Collector processors → Collector exporter → backend
```

Mark **every point where data can be dropped**. There are at least five. That
diagram is the debugging map for the rest of the module and for the break-fix.

## Sources — specific, not "read the docs"

- Traces API and SDK specification, sections on Span, SpanKind, and links
- W3C Trace Context, section 3.2 (`traceparent`)
- Collector documentation: the pipeline model, and the `memory_limiter` README —
  read the ordering warning there, it is the break-fix

## Why this lab exists

The rest of the module is hands-on. This is the one place where the conceptual
model has to go in first, because OTel failures are almost always "the data went
somewhere I did not know existed".
