# Lab 16.01 — A designed experiment

**CORE · 55 min**

## Context

Game Day I and the rounds that follow are **drills**: something breaks, you
react. That trains diagnosis, which is most of on-call.

Chaos engineering proper is a different discipline. A drill tells you how good
you are at reacting. An experiment tells you whether the system's resilience
claims are **true** — and only one of those scales, because an experiment can run
unattended and repeatedly.

## The problem

### Part 1 — define steady state

Not "the system is up". A measurable property with a threshold, from your module
07 SLIs.

1. Which SLI, and what value counts as steady?
2. Over what window? Why that one?
3. How do you observe it during the experiment, in real time?

Example: *probe freshness stays above 99.5% measured over rolling 5 minutes.*

### Part 2 — state a falsifiable hypothesis

Pick something the platform is supposed to survive:

> **Hypothesis:** if we lose one worker node, steady state holds.

4. Write yours. It must be falsifiable — an outcome that would prove it wrong.
5. What do you *expect* to happen mechanically? Which components react, in what
   order, and how fast?

Question 5 is the part that makes this science rather than poking: you are
predicting the mechanism, not just the outcome.

### Part 3 — bound the blast radius, before running

6. What is the smallest experiment that could falsify the hypothesis?
7. What is the abort condition? Define it numerically, in advance.
8. How do you abort? Write the exact command. Test that it works **before** you
   need it.
9. What is the worst realistic outcome? Are you willing to accept it?

Question 8 is not optional. An abort procedure you have not tested is a
hypothesis of its own.

### Part 4 — run it

```bash
# Observe steady state for a baseline period first
# Then, and only then:
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```

Record continuously: the steady-state metric, what you predicted, what happened.

10. Did steady state hold?
11. Did the mechanism match your prediction from question 5? If not, **that is a
    finding even if the hypothesis held** — you did not understand your own
    system.

Question 11 is the most valuable outcome of a chaos experiment and the one people
discard because "it worked".

### Part 5 — three more hypotheses

Design and run three of these:

| Hypothesis | Injection |
|---|---|
| Losing the Postgres primary keeps API reads working | delete the pod |
| A 500ms latency spike on the database does not breach the SLO | inject delay |
| Losing one Collector replica loses no telemetry | scale it down |
| Argo CD being down does not affect serving traffic | scale it to zero |

12. Which hypothesis was **wrong**? That is the one worth the whole lab.

### Part 6 — write it up

`modules/16-game-day/EXPERIMENTS.md`, in English: steady state, hypothesis, blast
radius, abort condition, result, and what changed as a consequence.

## Expected outcome

Four experiments with hypotheses stated before running, at least one falsified,
predicted mechanisms compared against observed, and `EXPERIMENTS.md` written.

## The distinction to carry away

<details><summary>After you have run them</summary>

A drill measures **you**. An experiment measures the **system**. Both are
necessary and they are not substitutes: a team that only drills has excellent
responders and unknown resilience; a team that only experiments has verified
resilience and nobody who has practised responding at 3am.

The scaling difference: experiments can run automatically, on a schedule, without
a human — which is how resilience claims stay true as the system changes.
</details>
