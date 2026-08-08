# Module 16 — Game Day II & Hardening

**5 blocks.** Requires everything, including [Game Day I](../08c-game-day-i/README.md).

No new technology. This module is the exam, and it is the module that produces
the artifact you actually show people.

This is the **second** Game Day. You ran one in week 15 against a seven-layer
system; this one covers all thirteen. Put the two postmortems side by side when
you finish — the change in time-to-diagnosis across thirteen weeks is the most
honest measure of progress in this repository.

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

`scripts/gameday-2.sh` injects failures at random from a pool spanning every
layer of the finished platform:

| Layer | Example failure class | From module |
|---|---|---|
| Kubernetes | Probes, scheduling, resource limits | 04, 06 |
| Networking | Gateway route attachment, Service selectors | 05 |
| Observability | Cardinality explosion, collector pipeline order | 07, 08 |
| Below the application | TCP accept queue — invisible to instrumentation | 08b |
| Delivery | Self-heal reverting a fix, canary analysis not scoped | 10, 11 |
| Supply chain | Policy silently in Audit rather than Enforce | 12 |

Unlike Game Day I, **several of these interact**: one can mask another, and the
order you fix them changes what you can observe.

Rules:

- You do not read the injection script beforehand.
- You start a timer at injection and record every command you run.
- You mitigate first and root-cause second — that ordering is the discipline.
- You write the postmortem within the same session, while it is fresh.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Reconstrucción completa, cronometrada](./labs/00-repaso.md) | CORE | 60 min |
| 01 | [**A designed experiment**](./labs/01-experiment.md) — hypothesis first, then break it | CORE | 55 min |
| 02 | [Ronda 1: tres fallos sobre trece capas](./labs/02-round-1.md) | CORE | 60 min |
| 03 | [Ronda 2: cinco fallos, sin red](./labs/03-round-2.md) | CORE | 50 min |
| 04 | [Postmortem y remediación](./labs/04-postmortem.md) | CORE | 50 min |
| 05 | [¿Cumplió la plataforma sus propios objetivos?](./labs/05-slo-review.md) | CORE | 40 min |
| 06 | [**The architecture review**](./labs/06-architecture-review.md) | CORE | 45 min |

### Lab 01 — the difference between a drill and an experiment

Game Day I and rounds 1–2 here are **drills**: something breaks, you react. That
trains diagnosis, which is most of the job.

Chaos engineering proper is the other thing, and it is a discipline rather than
an exercise:

1. Define the **steady state** as a measurable property — not "the system is up",
   but "the probe-freshness SLI stays above 99.5%".
2. State a **hypothesis**: "if we lose one worker node, steady state holds."
3. Define the **blast radius** and the abort condition *before* running.
4. Run the smallest experiment that could falsify the hypothesis.
5. Either the hypothesis held — which is evidence, not luck — or you found a
   real weakness.

The difference that matters: a drill tells you how good you are at reacting; an
experiment tells you whether the system's resilience claims are true. You need
both, and only one of them scales.

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

`POSTMORTEM-2.md`, `EXPERIMENTS.md`, `SLO-REVIEW.md`, and a final
`ARCHITECTURE.md` covering the whole platform with the trade-offs taken at each
layer.

That architecture document is the single most useful artifact in this repository
for an interview. Everything before it exists to make it true.

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
