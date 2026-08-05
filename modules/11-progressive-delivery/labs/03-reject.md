# Lab 11.03 — Measure the blast radius

**CORE · 50 min**

## Context

"The canary rejected it" is not a result. "The canary rejected it after 900
requests reached the broken version, out of 41,000 served" is.

## The problem

### Part 1 — instrument the experiment

Before deploying anything broken, set up measurement so the numbers are real:

```bash
# Sustained, known-rate traffic
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- -T2 http://pulse-api:8080/api/checks >/dev/null 2>&1 \
    && echo ok || echo FAIL; sleep 0.05; done'
```

Record the baseline request rate. You need it to convert percentages into
request counts.

### Part 2 — reject a broken release

Deploy an image that fails 100% of `/api/checks`. Record:

| Measure | Value |
|---|---|
| Step at which it was rejected | |
| Wall time from deploy to rejection | |
| Canary weight at rejection | |
| **Requests that hit the broken version** | |
| Total requests during the window | |
| Percentage of users affected | |

That fourth row is the number that matters, and the one nobody measures.

### Part 3 — vary one thing at a time

Rerun with each change and record the blast radius:

| Configuration | Requests affected |
|---|---|
| Baseline (from part 2) | |
| First step 25% instead of 10% | |
| `initialDelay` 30s instead of 2m | |
| `interval` 30s, `count` 2 | |
| `failureLimit: 1` instead of 0 | |

1. Which change increased blast radius most?
2. Which reduced it, and what did it cost?
3. `initialDelay` shorter than the rate window: what did you observe? Does it
   match the break-fix?

### Part 4 — the trade-off curve

4. Plot, even roughly: blast radius against total rollout time. What shape?
5. Where would you sit for Pulse? Justify against the SLO.
6. What would move you toward faster? Toward safer?

### Part 5 — a subtler broken release

Now one that fails only 3% of requests, not 100%.

7. Did the canary catch it? At which step?
8. How many requests before rejection? Compare against the 100% case.
9. What is the *smallest* error rate your configuration can detect, given your
   traffic and window? Derive it.

Question 9 is the honest limit of your gate, and you should know the number.
Below it, the canary is decoration and burn-rate alerting is what protects you.

## Expected outcome

Blast radius measured in requests for five configurations, the trade-off curve
sketched, and the minimum detectable error rate derived.

## Staged hints

<details><summary>Hint 1 — question 9</summary>

You need enough canary requests in the window to distinguish signal from noise.
At 50 rps with 10% weight and a 2m window you have ~600 canary requests; a 3%
error rate is ~18 failures, which is distinguishable. At 1% weight you have 60
requests and ~2 failures, which is not. **The detection floor is a function of
traffic, weight and window** — and it is why low-traffic services cannot be
protected by canary analysis alone.
</details>

<details><summary>Hint 2 — question 4</summary>

Roughly hyperbolic: halving blast radius costs more than double the time, because
you are both lowering the first step's weight and lengthening the measurement.
There is no free improvement, which is why the answer has to come from the SLO
rather than from preference.
</details>

## Cleanup

```bash
kubectl delete pod load -n pulse --ignore-not-found
kubectl argo rollouts undo pulse-api -n pulse
```
