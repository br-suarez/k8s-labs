# Module 16 — Game Day II & Hardening

**4 blocks.** Requires everything, including [Game Day I](../08b-game-day-i/README.md).

No new technology. This module is the exam, and it is the module that produces
the artifact you actually show people.

This is the **second** Game Day. You ran one in week 14 against a six-layer
system; this one covers all twelve. Put the two postmortems side by side when you
finish — the change in time-to-diagnosis across fourteen weeks is the most honest
measure of progress in this repository.

## Objectives

1. Diagnose failures across the whole stack under time pressure, without knowing
   in advance what broke.
2. Produce an incident timeline and a postmortem worth reading.
3. Turn findings into changes that prevent recurrence.
4. Assess the platform honestly against its own SLO.

## Exit criteria

- [ ] I diagnose and mitigate five injected failures, from five different layers,
      without being told what they are.
- [ ] Median time to diagnosis is under 15 minutes.
- [ ] I produce a blameless postmortem with a timeline, root cause, contributing
      factors and concrete actions.
- [ ] I can present the platform end to end — architecture, SLOs, delivery
      pipeline, security posture — as I would in an architecture review.

## Format

`scripts/gameday.sh` injects one failure at random from a pool spanning every
layer:

| Layer | Example failure class |
|---|---|
| Infrastructure | Node pressure, disk exhaustion |
| Kubernetes | Scheduling failure, evicted pods, stuck finalizer |
| Networking | Gateway misroute, DNS failure, policy drop |
| Application | Latency injection, queue saturation, dependency failure |
| Delivery | Bad release that passes the canary gate |
| Supply chain | Unsigned image blocked, or a policy that blocks everything |

Rules:

- You do not read the injection script beforehand.
- You start a timer at injection and record every command you run.
- You mitigate first and root-cause second — that ordering is the discipline.
- You write the postmortem within the same session, while it is fresh.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso: full-stack rebuild from empty cluster to running Pulse, timed | CORE | 60 min |
| 01 | Game Day round 1 — three failures | CORE | 60 min |
| 02 | Game Day round 2 — two failures, harder | CORE | 50 min |
| 03 | Postmortems and remediation | CORE | 50 min |
| 04 | SLO review: did the platform meet its own targets across the track? | CORE | 40 min |
| 05 | The architecture review presentation | CORE | 45 min |

## Capstone: final state

The platform is complete. It:

- runs multi-service on Kubernetes, routed by Gateway API
- keeps state with a proven restore path
- emits its own metrics and traces, correlated
- has an SLO, and alerts on burn rate rather than on symptoms
- is delivered by GitOps with canary analysis and automated rollback
- runs only signed images, enforced at admission
- is provisioned entirely by Terraform, locally and in GCP
- has been broken deliberately, repeatedly, and fixed

## The deliverable

`POSTMORTEM.md` per Game Day round, and a final `ARCHITECTURE.md` covering the
whole platform with the trade-offs taken at each layer.

That architecture document is the single most useful artifact in this repository
for an interview. Everything before it exists to make it true.

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
