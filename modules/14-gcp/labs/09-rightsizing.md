# Lab 14.09 — What you reserved versus what you use

**CORE · 50 min · $0**

## Context

Resource requests reserve capacity, and reserved capacity is what you pay for.
The gap between requested and used is money, and you have the metrics to measure
it exactly.

## The problem

### Part 1 — measure the gap

```promql
# Requested
sum by (pod) (kube_pod_container_resource_requests{resource="cpu", namespace="pulse"})

# Actually used, p95 over a week
quantile_over_time(0.95,
  sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pulse"}[5m]))[7d:5m])
```

Build the table:

| Workload | CPU req | CPU p95 | Ratio | Mem req | Mem p95 | Ratio |
|---|---|---|---|---|---|---|
| pulse-api | | | | | | |
| pulse-worker | | | | | | |
| postgres | | | | | | |

1. Which workload is furthest from its request?
2. What is the total reserved-but-unused CPU and memory across the namespace?

### Part 2 — put a number on it

3. At your cloud's rate, what does that gap cost per month? Per year?
4. What proportion of your total bill is it?

Do the arithmetic explicitly. "We are over-provisioned" is an opinion; "$1,840 a
year sits idle" starts a conversation.

### Part 3 — resize carefully

5. Set requests based on p95, not the mean. Why p95 and not the mean? Why not
   the max?
6. Apply and observe for a full cycle. What happened to scheduling? To
   throttling?

```promql
rate(container_cpu_cfs_throttled_seconds_total{namespace="pulse"}[5m])
```

7. Did throttling appear? If so, you cut too far — and this is the module 04
   lesson arriving with a price tag.

### Part 4 — the limit that is not a saving

8. Does raising or lowering a **limit** change what you pay? Why or why not?
9. What does raising a limit change, then?

Question 8 catches a common confusion: on a per-node billing model you pay for
the node, and requests determine how many nodes you need. Limits shape runtime
behaviour, not the bill.

### Part 5 — where it stops being about cost

10. You could cut requests by 40% and save real money. What do you lose?
11. What is the relationship between headroom and your error budget?
12. Where would you refuse to optimise, and how would you justify that to
    someone looking only at the bill?

Question 12 is the point of the lab. An SRE who cannot argue *against* a cost cut
on reliability grounds is not doing the job either.

## Expected outcome

A request-versus-usage table, the gap costed per year, a careful resize with
throttling checked, and a written position on where you would refuse to cut.

## Staged hints

<details><summary>Hint 1 — question 5</summary>

The mean under-provisions for normal peaks, so you get throttling during ordinary
traffic. The max provisions for a once-a-month event and wastes the rest of the
time. p95 or p99 covers routine variation while letting genuine spikes borrow
from the limit — which is precisely what Burstable QoS is for.
</details>

<details><summary>Hint 2 — question 11</summary>

Headroom is what absorbs a traffic spike, a node failure or a slow dependency
without breaching the SLO. Cutting it converts a cost saving into error-budget
consumption. If the budget is already tight, the cut is not a saving — it is
borrowing against reliability, and that is the framing to bring to the
conversation.
</details>
