# Module 08b — Game Day I

**2 blocks.** Requires modules 00–08. No new technology.

## Why this module exists here

The most valuable module in this track is the final Game Day — it is the only
one that directly produces the exit criteria: debugging a failure you have not
seen, under time pressure. It is also in week 26, which is exactly where the
slip protocol sacrifices things.

Putting the highest-value exercise where it is most likely to be dropped is a
design flaw. This module fixes it.

Three further reasons it belongs here rather than only at the end:

1. **You practise diagnosis on a system you can still hold in your head.** Six
   layers, not twelve. Learning to work an incident is easier before the surface
   area explodes.
2. **If the plan slips, you have already done one.** The final Game Day becomes
   a second attempt rather than a first.
3. **Two postmortems, fourteen weeks apart, are measurable evidence of
   progress.** Time to diagnosis in week 14 versus week 26 is the most honest
   number in this repository.

## Objectives

1. Diagnose failures across the stack without knowing in advance what broke.
2. Mitigate before root-causing, and know why that order matters.
3. Produce a postmortem someone else could act on.

## Exit criteria

- [ ] I diagnose and mitigate three injected failures without reading the
      injection script.
- [ ] Median time to diagnosis is under 20 minutes. (The final Game Day asks for
      under 15 — this is the baseline you improve on.)
- [ ] Every command I ran is recorded, in order, with what I expected and what I
      saw.
- [ ] I produce a blameless postmortem with timeline, root cause, contributing
      factors and concrete actions.

## Scope of the failures

Everything injected comes from modules 00–08. No surprises from material you
have not covered:

| Layer | From module |
|---|---|
| Probes and rollout behaviour | 04 |
| Services and endpoints | 04 |
| Gateway route attachment | 05 |
| Resource limits and OOM | 04, 06 |
| Service DNS and configuration | 04 |
| Queue saturation | 07, 08 |

## Format

```bash
# Confirm you are starting from health
./platform/scripts/verify.sh

# Inject. Start your timer.
./scripts/gameday-1.sh inject 3
```

**Do not read `scripts/gameday-1.sh`.** Reading it turns a diagnostic exercise
into a reading exercise. Run it, work the incident, and read it afterwards to
check whether your diagnosis matched what actually happened.

Rules:

- Record every command, in order, with your hypothesis before running it.
- **Mitigate first, root-cause second.** In a real incident, restoring service
  comes before understanding — and doing it in the wrong order is the most
  common failure of engineers who are technically strong.
- Write the postmortem in the same session, while it is fresh.
- `./scripts/gameday-1.sh restore` when finished.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) — full-stack rebuild, timed | CORE | 20 min |
| 01 | [Round 1](./labs/01-round-1.md) — three failures | CORE | 60 min |
| 02 | [Postmortem](./labs/02-postmortem.md) and remediation | CORE | 40 min |

## Capstone layer

No new layer. The deliverable is `POSTMORTEM-1.md` and whatever remediation you
land as a result — including any check you add to `platform/scripts/verify.sh`
because the incident revealed a blind spot.

That last part matters: a Game Day that does not change the system afterwards
was entertainment.

## Verification

```bash
./scripts/gameday-1.sh restore
./platform/scripts/verify.sh
```

Everything green, and `POSTMORTEM-1.md` committed.

---

## Problem → Solution → What I Learned

> The postmortem itself is the portfolio artifact. This section is what you
> learned about *how you work an incident*, which is different from what broke.

### Problem

### Solution

### What I Learned
