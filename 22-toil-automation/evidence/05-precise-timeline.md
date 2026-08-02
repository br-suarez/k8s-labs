# Evidence 05 — Precise unattended timeline

`02-e2e-timeline.txt` reports `alert firing -> report ready : 0s`. That number is
**an artefact of the measurement, not a real result**: that script polls every
20s, and the report already existed the first time it looked. It is recorded
here rather than quietly deleted, because a suspiciously perfect number is
exactly the kind of thing that should be re-measured instead of published.

Reconstructed from two sources that carry their own timestamps:

**1. When the alert actually started firing** — the `ALERTS` series in Prometheus,
queried at 15s resolution:

```
ALERTS{alertname="SLODemoAvailabilityFastBurn",alertstate="firing"}
  first sample: 05:24:45Z
```

**2. What the receiver did** — from its own log:

```
[20260802T052457Z] received 1 alert(s), status=firing
[20260802T052457Z] running triage for alert=SLODemoAvailabilityFastBurn service=slo-demo ns=slo-demo
[20260802T052457Z] triage complete in 0.57s -> /reports/20260802T052457Z-SLODemoAvailabilityFastBurn.txt
```

## Chain

| Time (UTC) | Event | Delta |
|------------|-------|-------|
| 05:18:01 | `error_rate=1.0` injected | — |
| 05:23:15 | alert enters `pending` (5m and 1h windows both above 7.2%) | +5m 14s |
| **05:24:45** | alert enters `firing` (`for: 2m` elapsed) | +1m 30s |
| 05:24:57 | Alertmanager delivers the webhook | **+12s** |
| 05:24:58 | triage report complete on disk (0.57s run) | **+13s** |

## Result

**13 seconds from page to complete diagnosis, with nobody awake.**

The 12s of that is Alertmanager's `groupWait: 10s` plus evaluation and delivery —
a deliberate batching delay, not overhead that could be optimised away without
losing alert grouping. The triage itself takes 0.57s.

For comparison, in the manual path this interval is bounded below by however long
it takes a human to notice the page, and the diagnosis does not start until they
have opened a terminal.

## What the report caught

The generated report ([`04-triage-report.txt`](./04-triage-report.txt)) correctly
identified a systemic, not per-pod, failure:

```
== 2. SCOPE — one pod or all of them?
  error ratio per pod (1m):
    slo-demo-6c776466f4-ll5hq  1
    slo-demo-6c776466f4-9zxzf  1
    slo-demo-6c776466f4-666m6  1
  → all pods similar  = systemic (bad deploy, dependency, config)

== 3. ERROR BUDGET — roll back, or fix forward?
    budget remaining (6h proxy): -11.416670403396068
    burn rate (1h):              20.53x
    ⚠ BUDGET BELOW 25% — policy says stop shipping and roll back.
```

All three pods at a 1.0 error ratio — every request failing, on every replica.
`kubectl get pods` reported all three `READY=true` with `RESTARTS=0` throughout.
