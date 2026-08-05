# Lab 11.06 — Three ways to promote a broken release

**EXTEND · 40 min**

> Do this **after** the break-fix. It generalises what that scenario taught into
> a diagnostic you can run on any canary configuration.

## Context

When a canary promotes something it should not have, there are exactly three
candidates: the metric, the threshold, or the timing. This lab makes you produce
each one deliberately and learn to tell them apart from the evidence.

## The problem

Deploy a canary that fails 100% of `/api/checks`. Then, one at a time, break the
analysis so that it promotes — three different ways.

### Failure 1 — the metric is wrong

Remove the `rollouts_pod_template_hash` filter so the query measures global
error rate.

1. What values does the analysis record at each step?
2. What is the relationship between those values and `setWeight`?

### Failure 2 — the threshold is wrong

Restore the filter. Set `successCondition: result[0] < 0.95`.

3. What values now? How do they differ from failure 1?

### Failure 3 — the timing is wrong

Restore the threshold. Set `initialDelay: 10s` with `rate(...[5m])`.

4. What values? How do they compare to the real canary error rate during the
   same window?

## The diagnostic

You now have three sets of recorded values from the same broken release. Build
the table that tells them apart:

| Symptom | Metric | Threshold | Timing |
|---|---|---|---|
| Values grow proportionally to `setWeight` | ✓ | | |
| Values are correct but below the threshold | | ✓ | |
| Values are low at first and climb across measurements | | | ✓ |
| Values match reality and it still promoted | | ✓ | |

Fill it in from what you actually observed, then answer:

5. Which two are hardest to distinguish? What extra evidence separates them?
6. Given only the recorded analysis values and no access to the cluster, could
   you diagnose it? What would you need?

### The reusable procedure

Write in `NOTAS.md` the checklist you would follow when a canary promotes
something bad:

```
1. Get the values the analysis recorded at each step
2. Get the metric's real value in the canary during those windows
3. Compare:
   - measured ≈ real, below threshold  → threshold
   - measured ≪ real, ∝ setWeight      → metric not scoped
   - measured ≪ real, climbing         → timing
4. Verify the fix with a deliberately broken image before trusting it again
```

Step 4 is not optional. A canary that failed once has lost the team's trust, and
only a demonstrated rejection gets it back.

## Expected outcome

Three deliberate false promotions with their recorded values, a completed
discrimination table, and the reusable checklist.

## Staged hints

<details><summary>Hint 1 — question 5</summary>

Threshold and timing both produce "measured value looks lowish and it passed".
What separates them: with a threshold problem the value is **stable and correct**
across measurements; with a timing problem it **climbs** as the window fills with
canary data. If you only have the final measurement you cannot tell — which is
the argument for recording every measurement, not just the verdict.
</details>
