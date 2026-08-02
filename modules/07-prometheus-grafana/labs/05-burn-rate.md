# Lab 07.05 — Multi-window burn rate

**CORE · 45 min**

## Context

You did this in `archive/sre-track/20-slo-error-budgets/` with 35% injected
errors and a 14.4x page. This time the SLI is one **you** designed in lab 03, on
a system where the obvious SLI was wrong. That is the harder half.

## The problem

### Part 1 — the budget

For your API availability SLO (start with 99.9% over 30 days):

1. How many minutes of downtime does the budget allow?
2. What burn rate exhausts it in exactly 30 days? In 1 day? In 1 hour?
3. Fill in the standard table and derive each row rather than copying it:

| Burn rate | Budget consumed | Long window | Short window | Severity |
|---|---|---|---|---|
| 14.4 | 2% in 1h | 1h | 5m | page |
| 6 | 5% in 6h | 6h | 30m | page |
| 3 | 10% in 1d | 1d | 2h | ticket |
| 1 | 100% in 30d | 3d | 6h | ticket |

### Part 2 — as code

Write the `PrometheusRule`. Both windows must be over threshold for the alert to
fire.

```yaml
- alert: PulseAPIErrorBudgetBurnFast
  expr: |
    (
      pulse:api_error_ratio:rate1h > (14.4 * 0.001)
      and
      pulse:api_error_ratio:rate5m > (14.4 * 0.001)
    )
  for: 2m
```

Build the recording rules the alert depends on. Note how lab 04's work pays off
here — alerts over recorded series evaluate fast and consistently.

### Part 3 — prove it fires

```bash
# Inject a real error rate into pulse-api
kubectl set env deployment/pulse-api -n pulse INJECT_ERROR_RATE=0.35
```

Measure and record:

- Time from injection to `pending`
- Time from `pending` to `firing`
- The burn rate value at firing
- Time from fix to resolved

Then remove the injection and watch the short window resolve it **while the long
window is still over threshold**. That asymmetry is the entire reason for two
windows — capture it.

### Part 4 — prove it does NOT fire

Equally important, and usually skipped.

1. A 30-second blip at 100% errors. Does it page? Should it?
2. A sustained 0.05% error rate, well inside budget. Does it page? Should it?
3. One monitored customer endpoint goes down permanently. Does it page? **It must
   not** — if it does, go back to lab 03, your SLI is still wrong.

Test 3 is the one that validates the whole module.

## Expected outcome

Alerts as code, four measured timings from a real injection, and three
verified non-firing cases.

## Verification

```bash
kubectl get prometheusrule -n monitoring
curl -s localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.type=="alerting") | {name, state}'
```

## Staged hints

<details><summary>Hint 1 — deriving the burn rate</summary>

Burn rate = (observed error ratio) / (1 − SLO). At 99.9%, the budget is 0.001.
An observed 1.44% error rate is a burn rate of 14.4, which consumes the 30-day
budget in 30/14.4 ≈ 2 days — and 2% of it in one hour. Derive the rest the same
way rather than memorising the table.
</details>

<details><summary>Hint 2 — the short window</summary>

The short window is typically 1/12 of the long one. Its job is not detection but
**resolution**: without it, the alert stays firing for the whole long window
after the problem is fixed. An alert that stays lit for an hour after recovery is
one people learn to ignore.
</details>
