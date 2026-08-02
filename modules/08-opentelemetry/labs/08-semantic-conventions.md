# Lab 08.08 — Semantic conventions

**EXTEND · 30 min**

> Skip if behind schedule. Short, and it is what makes your telemetry portable
> between backends and readable by people who did not write it.

## Context

`http.method`, `http_method`, `method`, `httpMethod` — four ways to say the same
thing, and a dashboard that works on one service and not the next. Semantic
conventions are the shared vocabulary that fixes this.

## The problem

### Part 1 — audit what you emit

```bash
curl -s "http://tempo:3200/api/search?tags=" | jq -r '.traces[0].traceID' \
  | xargs -I{} curl -s "http://tempo:3200/api/traces/{}" \
  | jq -r '.batches[].scopeSpans[].spans[].attributes[].key' | sort -u
```

List every attribute key Pulse emits. For each: is it a semantic convention, and
if so, is it the current name?

### Part 2 — the stability problem

Several HTTP attributes were renamed when the HTTP semantic conventions
stabilised — `http.method` became `http.request.method`, `http.status_code`
became `http.response.status_code`, and others moved similarly.

1. Which of your attributes use superseded names?
2. Which Go `semconv` package version are you importing? Check the import path —
   it carries the version.
3. If you rename them, what breaks in the dashboards you already built?
4. How would you migrate without a flag day? (There is a documented approach for
   emitting both during a transition.)

### Part 3 — Pulse-specific attributes

Not everything has a convention. Pulse needs attributes nobody standardised:
which check, which tenant, which probe outcome.

Design them:

5. What prefix do you use, and why not a bare name?
6. Which of your custom attributes should actually be **Resource** attributes
   rather than span attributes?
7. Which are safe as metric labels, and which must stay trace-only? (Module 07's
   cardinality rule applies unchanged.)

### Part 4 — write it down

Create `platform/TELEMETRY.md`: every attribute Pulse emits, whether it is a
convention or custom, its cardinality, and where it is allowed to appear —
span, metric label, or both.

That document is what stops the next person adding `url` as a metric label,
which is exactly module 07's break-fix.

## Expected outcome

An audit of current attributes, superseded names identified, a custom namespace
designed, and `TELEMETRY.md`.

## Staged hints

<details><summary>Hint 1 — question 4</summary>

The convention during migration is to emit both old and new names for a period,
controlled by an environment variable, so dashboards can be updated
independently of the deploy. The Go SDK supports this via
`OTEL_SEMCONV_STABILITY_OPT_IN`. The general lesson — dual-write during a
rename, cut over, then remove — applies far beyond telemetry.
</details>

<details><summary>Hint 2 — question 6</summary>

Resource attributes describe **the thing emitting** telemetry and are identical
for every span from that process: service name, version, pod, region. Span
attributes describe **this operation**: which check, which URL, which outcome.
Putting a per-operation value on the Resource is wrong and, in most SDKs,
impossible to vary — which is a useful clue when deciding.
</details>

## Why this lab exists

Conventions are what let a Grafana dashboard written by someone else work on your
service without modification. They are also what makes an OTel migration between
backends a configuration change rather than a rewrite.
