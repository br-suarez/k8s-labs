# Module 07 — Prometheus & Grafana

**4 blocks.** Requires module 04.

The reference repos only cover Prometheus at the Docker Compose level (cAdvisor
and node-exporter via dockprom). In-cluster monitoring — the Operator,
ServiceMonitors, recording rules — is not covered anywhere. This module is built
from scratch.

## Objectives

1. Run the Prometheus Operator stack in a memory-constrained cluster and know
   which knobs control its footprint.
2. Instrument Pulse properly, replacing the hand-written exporter with the
   official client.
3. Define an SLI and an SLO that survive contact with reality.
4. Make a slow dashboard fast, and explain the mechanism.

## Exit criteria

- [ ] I can write a recording rule that takes a dashboard panel from 8s to under
      1s and explain exactly why it works.
- [ ] I can define an SLI for Pulse that does **not** page when a monitored
      target goes down — only when Pulse itself is failing.
- [ ] I can write a multi-window burn-rate alert and justify both windows.
- [ ] Given a metric that "disappeared", I can trace it back through
      ServiceMonitor → scrape config → target → endpoint.

## The central problem of this module

Pulse monitors other things. A naive availability SLI — "percentage of successful
probes" — pages you every time a *monitored* endpoint goes down. That is not your
outage. Separating "Pulse is broken" from "the thing Pulse watches is broken" is
the actual work, and it is the difference between an SLO people trust and one
they mute.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) (módulos 05–06) | CORE | 15 min |
| 01 | [The stack, on a small cluster](./labs/01-install-stack.md) — every value you reduce, and what it costs | CORE | 45 min |
| 02 | [Replace the hand-rolled exporter](./labs/02-instrument.md) — diff your own work against the official client | CORE | 45 min |
| 03 | [**Whose failure is it?**](./labs/03-sli-slo.md) — the conceptual centre of the module | CORE | 50 min |
| 04 | [Make a slow dashboard fast](./labs/04-recording-rules.md) — measured, both directions | CORE | 50 min |
| 05 | [Multi-window burn rate](./labs/05-burn-rate.md) — and proving it does *not* fire | CORE | 45 min |
| 06 | [Blow it up on purpose](./labs/06-cardinality.md) — cardinality, and the three defences | EXTEND | 40 min |
| 07 | [The metric that disappeared](./labs/07-missing-metric.md) | EXTEND | 35 min |

## Low-memory note

If you are on the `lite` profile, use these values and record that you did:
`prometheus.retention=6h`, `prometheus.resources.limits.memory=1Gi`,
`grafana.persistence.enabled=false`, and disable the default
`kubeStateMetrics` dashboards you are not using. The labs all work; you just
cannot keep two weeks of history.

## Capstone layer

Pulse emits real Prometheus metrics, scraped via ServiceMonitor, with an SLO
defined as code and a burn-rate alert that fires on injected failure.

## Verification

```bash
./platform/scripts/verify.sh slo
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
