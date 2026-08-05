# Lab 11.05 — Blue/green, and when canary is wrong

**EXTEND · 45 min**

> Skip if behind schedule. The comparison is a common architecture-review
> question and worth having a real answer to.

## Context

Canary assumes two versions can coexist and serve the same users. That
assumption is often false, and knowing when is the skill.

## The problem

### Part 1 — implement blue/green

Convert `pulse-api` to a blue/green Rollout:

```yaml
strategy:
  blueGreen:
    activeService: pulse-api
    previewService: pulse-api-preview
    autoPromotionEnabled: false
    prePromotionAnalysis:
      templates: [{templateName: error-rate}]
    scaleDownDelaySeconds: 300
```

1. What is the preview service for? Who reaches it?
2. What does `scaleDownDelaySeconds` buy, and what does it cost?
3. How fast is a rollback compared to canary? Measure both.

### Part 2 — compare on real criteria

| | Canary | Blue/green |
|---|---|---|
| Peak resource usage | | |
| Rollback time (measured) | | |
| Users exposed to a bad release | | |
| Validation before any user traffic | | |
| Works with an incompatible schema change | | |
| Detects load-dependent problems | | |

Fill from observation, not from memory.

### Part 3 — the case canary cannot handle

Construct one. Change the results table schema so v1 and v2 interpret a column
differently, then run a canary.

4. What happened to the data?
5. Would any analysis configuration have caught it?
6. Why is blue/green also insufficient here, and what is the actual answer?

Question 6 matters: the real answer is expand/contract migrations — make the
schema compatible with both versions, deploy, then remove the old shape. Neither
strategy substitutes for that.

### Part 4 — decide for Pulse

7. Which for `pulse-api`? Defend it with numbers from part 2.
8. Which for `pulse-worker`? The answer differs — the worker has no inbound
   traffic to split, which changes the question entirely.
9. What would make you change your mind about `pulse-api`?

## Expected outcome

Both strategies implemented and measured, an incompatible-change failure
reproduced, and a defended per-service choice.

## Staged hints

<details><summary>Hint 1 — question 8</summary>

The worker pulls from a queue; there is no traffic to weight. "Canary" for a
consumer means running a small number of new-version consumers alongside old
ones and comparing their outcomes — which requires the queue to distribute
fairly and both versions to be safe on the same messages. Often the honest answer
is: stop the old consumers, start the new ones, and rely on the queue for
durability.
</details>

<details><summary>Hint 2 — question 2</summary>

Keeping the old ReplicaSet scaled up means rollback is a service selector switch
— seconds, no pod startup. The cost is running double capacity for that window,
which for a memory-heavy service on a small cluster may simply not fit.
</details>
