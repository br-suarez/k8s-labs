# Lab 11.04 — Derive the minimum safe pause

**CORE · 45 min**

## Context

`archive/sre-track/21-argocd-canary/` found a 3x blast-radius bug caused by a
pause shorter than the analysis time-to-verdict. This lab approaches it from the
other direction: derive the correct number from first principles, then prove it.

## The problem

### Part 1 — measure time-to-verdict

How long after a change does your metric reflect it? Measure, do not assume.

```bash
# t=0: inject errors into the canary
kubectl set env deployment/pulse-api-canary -n pulse INJECT_ERROR_RATE=1.0

# Poll the analysis query every 10s and record when it crosses the threshold
while :; do
  printf '%s ' "$(date +%T)"
  curl -s -G localhost:9090/api/v1/query \
    --data-urlencode 'query=<your analysis query>' | jq -r '.data.result[0].value[1]'
  sleep 10
done
```

Record the full chain:

| Stage | Delay |
|---|---|
| Error occurs → app counter increments | |
| Counter → Prometheus scrape | |
| Scrape → inside the `rate()` window enough to move the value | |
| Value crosses threshold | |
| **Total time-to-verdict** | |

### Part 2 — derive the rule

From those numbers:

1. What is the minimum `initialDelay` that guarantees the first measurement sees
   the canary's real behaviour?
2. What is the minimum total pause per step?
3. What happens if the pause is exactly the time-to-verdict? Why do you want
   margin?
4. Write the rule as a formula.

### Part 3 — prove it, both directions

Set the pause **below** your derived minimum and deploy a broken canary.

5. Did it promote? What did the analysis measure?
6. How does the measured value compare to the real canary error rate?

Now set it at the derived minimum and repeat.

7. Rejected? At which step?

### Part 4 — the interaction nobody expects

Your scrape interval is a floor on everything. If Prometheus scrapes every 60s,
no analysis can react faster than 60s regardless of configuration.

8. What is your scrape interval? What floor does it put on time-to-verdict?
9. If you lowered it to 15s, what would you gain and what would it cost?
   (Module 07 answered the cost side: series churn and storage.)
10. Is there a case for a separate, faster scrape target just for canary
    analysis? Argue both ways.

## Expected outcome

A measured time-to-verdict broken down by stage, a derived formula, and both
directions proven — too-short promotes, correct rejects.

## The formula to reach

<details><summary>After you have derived your own</summary>

```
time-to-verdict = scrape_interval
                + rate_window          (for the value to move meaningfully)
                + analysis_interval    (until the next measurement)

initialDelay   ≥ rate_window
pause_per_step ≥ time-to-verdict × safety_margin   (1.5–2x)
```

The safety margin exists because every term is a distribution, not a constant:
scrapes jitter, and a value that has "moved meaningfully" is not the same as one
that has fully converged. Promoting on a metric that is still climbing is exactly
the failure mode from module 21.
</details>

## Why this lab exists

Every parameter in a canary configuration is usually copied from an example. This
lab makes you derive four of them from measurements of your own system — which is
the difference between a canary that works and one that happens to have worked so
far.
