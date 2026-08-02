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
| 00 | [Repaso](./labs/00-repaso.md) (módulos 06–07) | CORE | 15 min |
| 01 | [Against the specification](./labs/01-concepts.md) — active reading, with a deliverable | CORE | 40 min |
| 02 | [Instrument by hand](./labs/02-instrument-api.md) — and measure what a span costs | CORE | 55 min |
| 03 | [The Collector pipeline](./labs/03-collector.md) — enrichment, redaction, and its own metrics | CORE | 50 min |
| 04 | [**Across the queue**](./labs/04-queue-propagation.md) — the lab this module exists for | CORE | 60 min |
| 05 | [Metric to trace, in one click](./labs/05-exemplars.md) — Tempo v3.0.2 and exemplars | CORE | 50 min |
| 06 | [Keep every error at 1% sampling](./labs/06-sampling.md) — head vs tail | CORE | 45 min |
| 07 | [When two sources of truth disagree](./labs/07-span-metrics.md) | EXTEND | 45 min |
| 08 | [Semantic conventions](./labs/08-semantic-conventions.md) | EXTEND | 30 min |

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
