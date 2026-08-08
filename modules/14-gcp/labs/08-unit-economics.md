# Lab 14.08 — Cost per 1,000 probes

**CORE · 55 min · $0**

## Context

Total cost tells you nothing on its own: it goes up when you grow, so it cannot
distinguish "we are wasting money" from "we are doing more work". Cost per unit
of work can.

Everything here analyses data you already produced. It costs nothing.

## The problem

### Part 1 — get the cost data

Export billing to BigQuery, or use the existing export if you have one.

```bash
bq query --use_legacy_sql=false '
SELECT service.description AS service,
       sku.description AS sku,
       SUM(cost) AS cost
FROM `PROJECT.billing.gcp_billing_export_v1_XXXX`
WHERE DATE(usage_start_time) BETWEEN "2027-01-01" AND "2027-01-31"
GROUP BY 1, 2 ORDER BY cost DESC LIMIT 20'
```

1. What are your top five line items? Does the ranking surprise you?
2. Which of them scale with **usage**, and which are fixed regardless?

Question 2 is the split that matters: fixed costs get worse per unit as you
shrink, variable costs are what optimisation targets.

### Part 2 — get the work data

From the module 07 metrics:

```promql
sum(increase(pulse_worker_probes_total[30d]))
```

3. How many probes in the same period?
4. How many API requests? How many results stored?
5. Which of those is the right denominator? Argue it.

Question 5 matters: pick the unit your customers would recognise as the thing
they are buying.

### Part 3 — the number

```
cost per 1,000 probes = total cost / (probes / 1000)
```

6. What is it?
7. Break it down: how much of that is compute, how much storage, how much
   network?
8. If you doubled the number of probes, what would the cost per 1,000 do? Predict
   first, then reason about which components are fixed.

### Part 4 — make it a metric

9. Publish it. A scheduled job that queries billing and Prometheus and exposes
   `pulse_cost_per_1k_probes` — so it lives on a dashboard next to the SLOs.
10. Why does it belong next to the SLOs rather than in a finance report?

Question 10's answer: because it is an input to reliability decisions. "Three
replicas instead of two" has a number attached, and without it the conversation is
opinion.

### Part 5 — use it

11. What is the cost of your current SLO? Estimate what a 99.99% target would
    cost versus 99.9% — more replicas, multi-zone, more headroom.
12. At what point does an extra nine cost more than the downtime it prevents?

Question 12 is the actual SRE question about cost, and being able to frame it
numerically is what makes an error budget a business conversation instead of an
engineering preference.

## Expected outcome

A cost-per-1,000-probes figure with its breakdown, published as a metric next to
the SLOs, and a reasoned estimate of what the next nine would cost.

## Staged hints

<details><summary>Hint 1 — question 8</summary>

Cost per unit usually **falls** as volume grows, because fixed costs — the
cluster management fee, the minimum node, the load balancer — spread across more
work. That is also why a tiny service looks terrible per unit and why per-unit
figures are only comparable at similar scale.
</details>
