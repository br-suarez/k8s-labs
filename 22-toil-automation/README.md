# Lab 22: Toil Automation — Runbook Execution on Alert

**Module:** 22 — Toil Automation & Runbooks (SRE Track)
**Date:** 2026-08-02
**Stack:** Alertmanager webhooks, Python (stdlib), bash, kubectl, Prometheus, RBAC

---

## Problem

Module 20 ends with a runbook: when the availability page fires, run these
commands to work out what is happening. It is a good runbook. It is also
**11 commands that a human types by hand, in the same order, every single time**,
producing raw JSON that has to be mentally converted into percentages — usually
at an hour when nobody converts anything reliably.

That is toil in the precise sense, not the colloquial one: manual, repetitive,
automatable, interrupt-driven, leaving the system exactly as it was, and scaling
linearly with the number of services and alerts. All six properties check out —
the full argument, including what is deliberately *not* automated, is in
[`toil-analysis.md`](./toil-analysis.md).

The goal was not "write a script". It was to make the diagnosis **already exist**
by the time a human acknowledges the page — and then to measure whether that
actually happened rather than assert it.

---

## Solution

```
   SLO burn-rate alert fires (module 20)
              │
              ▼
        Alertmanager  ──── AlertmanagerConfig routes
              │              service=slo-demo, severity=critical
              │ webhook POST
              ▼
     triage-runner (ns monitoring)
       receiver.py  ── answers 200 immediately, works in a thread
              │
              ▼
        triage.sh  ── Prometheus queries + kubectl (read-only RBAC)
              │
              ▼
     formatted report -> /reports + stdout (kubectl logs)
```

| Path | What it is |
|------|-----------|
| [`triage/triage.sh`](./triage/triage.sh) | The automation — the module 20 runbook, executed and formatted |
| [`triage/receiver.py`](./triage/receiver.py) | Alertmanager webhook receiver, stdlib only |
| [`triage/manual-runbook.sh`](./triage/manual-runbook.sh) | The toil being replaced, kept for timing **and as the fallback** |
| [`deploy/rbac.yaml`](./deploy/rbac.yaml) | `get`/`list` only — no write verbs anywhere |
| [`deploy/alertmanager-config.yaml`](./deploy/alertmanager-config.yaml) | Routes SLO alerts to the webhook |
| [`toil-analysis.md`](./toil-analysis.md) | Is this toil? What is not automated, and why |

### Design decisions worth defending

**Read-only by construction.** The ClusterRole has `get` and `list` and nothing
else. The tool gathers evidence; it does not restart pods, roll back deploys, or
silence alerts. A diagnostic that gets it wrong wastes a minute — an
auto-remediation that gets it wrong turns a degradation into an outage.

**Standard library only.** `receiver.py` imports nothing that is not in Python
itself. Software that runs *during an incident* should have as few moving parts
as possible.

**Answer the webhook first, work second.** The handler returns `200` before
running anything. Alertmanager's webhook timeout is shorter than a kubectl-heavy
triage run, and a handler that blocks makes Alertmanager retry the whole batch.

**The manual runbook is not deleted.** If the receiver is down, the page still
arrives and a human still needs the commands. Removing the fallback would make
the automation a single point of failure for diagnosis.

---

## Results

### The measurement ([`01-toil-measurement.txt`](./evidence/01-toil-measurement.txt))

| | Manual | Automated |
|---|---|---|
| Commands a human types | **11** | **0** |
| Mechanical execution (avg of 3) | 1.34s | 0.68s |
| Output | 6 raw JSON blobs + 5 kubectl tables | one formatted report |
| Runs unattended | no | yes |

**A 2x mechanical speedup is not the benefit, and selling it as one would be
dishonest.** Eleven commands run back to back were never the bottleneck. What is
actually being spent is human time — acknowledging the page, finding the runbook,
pasting commands, and reading `"value":[1785640859.189,"0.13544611949047162"]`
to work out that it means 13.5%.

### The number that does matter ([`05-precise-timeline.md`](./evidence/05-precise-timeline.md))

Injected a 100% error rate and let the system run with nobody watching:

| Time (UTC) | Event | Delta |
|------------|-------|-------|
| 05:18:01 | `error_rate=1.0` injected | — |
| 05:23:15 | alert `pending` | +5m 14s |
| **05:24:45** | alert **`firing`** | +1m 30s |
| 05:24:57 | Alertmanager delivers webhook | **+12s** |
| 05:24:58 | complete triage report on disk | **+13s** |

**13 seconds from page to full diagnosis, unattended.** Twelve of those are
Alertmanager's `groupWait: 10s` plus delivery — deliberate batching, not waste.
The triage itself ran in 0.57s.

The report correctly called the failure systemic rather than per-pod:

```
== 2. SCOPE — one pod or all of them?
  error ratio per pod (1m):
    slo-demo-6c776466f4-ll5hq  1
    slo-demo-6c776466f4-9zxzf  1
    slo-demo-6c776466f4-666m6  1
  → all pods similar  = systemic (bad deploy, dependency, config)

== 3. ERROR BUDGET — roll back, or fix forward?
    burn rate (1h):  20.53x
    ⚠ BUDGET BELOW 25% — policy says stop shipping and roll back.
```

Every pod failing every request — while `kubectl get pods` showed all three
`READY=true`, `RESTARTS=0`, for the entire incident.

---

## Issues encountered

**1. The route was silently dead — valid config, zero delivery.**
The Prometheus Operator injects `namespace="<ns>"` into every route generated
from an `AlertmanagerConfig` CRD, so one tenant cannot capture another's alerts.
Reasonable. But the module 20 alerts carry **no `namespace` label at all** —
their expressions `sum()` it away and the rule only adds `severity`/`slo`/`service`:

```
labels: {"burn_rate":"14.4","long_window":"1h","service":"slo-demo",
         "severity":"critical","short_window":"5m","slo":"availability"}
```

So the injected matcher could never match. Alertmanager reported the config as
perfectly valid, the CRD showed as accepted, and the webhook would simply never
have been called. Fixed with `alertmanagerConfigMatcherStrategy.type: None` on
the Alertmanager spec — acceptable on a single-tenant cluster; a multi-tenant one
should give the alerts a namespace label instead of disabling the isolation.

**2. `COPY --from=bitnami/kubectl:1.34.1` no longer resolves.**
Bitnami retired its public Docker Hub images, so a pattern that is in a great
many Dockerfiles now fails with `not found`. Replaced with a pinned download from
`dl.k8s.io`, which does not depend on a third party's registry policy.

**3. The end-to-end script measured `0s` and it was wrong.**
`alert firing -> report ready : 0s` looked like a triumph. It was a 20s polling
interval finding the report already written. The honest interval — 13s — had to
be reconstructed from the Prometheus `ALERTS` series and the receiver's own log,
both of which carry their own timestamps instead of depending on how often my
script happened to look. The misleading run is kept in
[`02-e2e-timeline.txt`](./evidence/02-e2e-timeline.txt) with a correction
appended rather than deleted.

---

## What I learned

- **The honest benefit was not the one I set out to measure.** I expected to
  report "manual takes minutes, automated takes seconds". Timing both properly
  gave 1.34s vs 0.68s — a real number, and a nearly worthless one. The saving is
  in the 11 context switches and the raw-JSON-to-percentage conversion, and the
  intellectually honest way to present it is to publish the unimpressive
  measurement alongside the assumption-based estimate, clearly labelled as an
  estimate.

- **A resolution artefact reads exactly like a great result.** `0s` was the most
  impressive number the lab produced and it was meaningless. The fix — derive
  timings from sources that carry their own timestamps rather than from how often
  the observer polls — is the same discipline as not trusting an SLI computed
  over three requests.

- **"The config is valid" and "the config works" are unrelated claims.** The
  AlertmanagerConfig was accepted, rendered into `alertmanager.yaml`, and visible
  in the generated secret. It was also incapable of ever matching an alert. This
  is the same failure shape as module 21's `--set` on a key that no longer
  existed: both were silent, both looked correct, and both would only have been
  caught by testing the actual path end to end.

- **Automating diagnosis is safe; automating remediation is a different
  conversation.** Keeping the RBAC read-only forced the boundary to be explicit.
  The report ends by handing the operator branch points — "all pods similar =
  systemic" — rather than acting on them. That line is where reversible ends and
  irreversible begins.

- **Deleting the manual runbook would have been the mistake.** It is the fallback
  when the receiver is down, and it is what made the measurement possible at all.
  A toil automation that removes the ability to do the task by hand has not
  reduced risk, it has moved it.

---

## Reproduce

```bash
docker build -t triage-runner:v1 triage
kind load docker-image triage-runner:v1 --name slo-lab
kubectl apply -f deploy/rbac.yaml -f deploy/deployment.yaml -f deploy/alertmanager-config.yaml

./evidence/measure-toil.sh      # manual vs automated timing
./evidence/run-e2e.sh           # break the service, watch triage run itself
```

Requires module 20's SLO rules and Prometheus stack, including
`alertmanagerConfigMatcherStrategy.type: None` in
[`kube-prom-stack-values.yaml`](../20-slo-error-budgets/monitoring/kube-prom-stack-values.yaml).

Run triage by hand against any service:

```bash
kubectl exec -n monitoring deploy/triage-runner -- /app/triage.sh slo-demo slo-demo
```
