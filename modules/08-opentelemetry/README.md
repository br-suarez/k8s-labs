# Module 08 — OpenTelemetry

**6 blocks.** Requires module 07. The single largest gap in the reference
material — **zero coverage anywhere** — and weighted accordingly.

## Objectives

1. Instrument a real service with the OTel SDK by hand, not via auto-instrumentation.
2. Run a Collector and understand its pipeline model: receivers, processors,
   exporters.
3. Propagate context across a service boundary and through a queue — the case
   that breaks naive tracing.
4. Correlate a metric spike to the exact trace that caused it.

## Exit criteria

- [ ] I can add tracing to an uninstrumented Go service from scratch and get a
      complete trace across `pulse-api` → Redis → `pulse-worker`.
- [ ] I can explain the Collector's pipeline model and write a config that
      samples, filters and exports to two backends.
- [ ] Given a broken trace where the worker's spans are orphaned, I can diagnose
      the propagation failure.
- [ ] I can explain head vs tail sampling and pick correctly for a stated
      requirement.

## The hard part

Context propagates over HTTP through headers almost for free. Through a **queue**
it does not: the worker picks up a job with no live connection to the request
that created it. You have to serialise the trace context into the job payload and
restore it on the other side. Getting that right is the difference between three
disconnected traces and one that tells a story — and it is the thing most
tutorials skip because their example app is a single service.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 06–07) | CORE | 15 min |
| 01 | OTel concepts against the spec: signals, context, baggage, resource | CORE | 40 min |
| 02 | Instrument `pulse-api` by hand: tracer, spans, attributes, errors | CORE | 55 min |
| 03 | Deploy the Collector (v0.157.0); build a pipeline with a processor that does real work | CORE | 50 min |
| 04 | **Propagate across the queue** — the lab that matters | CORE | 60 min |
| 05 | Traces to Tempo, metrics to Prometheus, correlate with exemplars | CORE | 50 min |
| 06 | Head vs tail sampling: keep every error trace at 1% overall sampling | CORE | 45 min |
| 07 | Span metrics: derive RED from traces, compare against module 07's direct metrics, explain the disagreement | EXTEND | 45 min |
| 08 | Semantic conventions and why they matter for portability | EXTEND | 30 min |

## Capstone layer

Pulse emits its own traces end to end. A latency spike in a Grafana panel links
directly, via exemplar, to the trace that caused it — which is the payoff for
everything built in modules 07 and 08.

## Verification

```bash
./platform/scripts/verify.sh traces
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
