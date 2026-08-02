# Lab 05.05 — Traffic splitting by weight

**CORE · 45 min**

## Context

This is the mechanism module 11's canary is built on. Argo Rollouts does not
invent traffic splitting — it manipulates the weights you are about to write by
hand. Doing it manually first means that when the canary misbehaves, you know
which layer to inspect.

## The problem

### Part 1 — two versions

Deploy `pulse-api-stable` and `pulse-api-canary` as separate Deployments and
Services. Make them distinguishable — a version string in the response body or a
response header is enough.

### Part 2 — split it

```yaml
backendRefs:
  - name: pulse-api-stable
    port: 8080
    weight: 90
  - name: pulse-api-canary
    port: 8080
    weight: 10
```

Verify the actual distribution:

```bash
for i in $(seq 500); do
  curl -s -H 'Host: pulse.local' localhost:8080/api/version
done | sort | uniq -c
```

Record the observed split against the configured one. It will not be exactly
90/10. Explain why in `NOTAS.md`.

### Part 3 — the questions that matter for module 11

1. Is the split per **request** or per **connection**? Design an experiment that
   distinguishes them, and run it.
2. With HTTP keepalive, does a client's second request necessarily go to the same
   backend?
3. What happens to in-flight requests when you change the weights?
4. Set `weight: 0` on the canary. Is that the same as removing the backendRef?
   Test it — the answer is specified and is not what most people guess.
5. How long does a weight change take to become effective? Measure it.

### Part 4 — progressive by hand

Step the canary through 0 → 5 → 25 → 50 → 100, checking error rate at each step.
Time each transition.

**This is exactly what Argo Rollouts automates.** Doing it manually gives you the
number you need in module 11: how long a weight change takes to take effect, and
therefore the minimum a canary pause can safely be.

Write that number down. Module 11 asks for it.

## Expected outcome

- Observed versus configured distribution, with an explanation of the difference
- The five questions answered experimentally
- A measured weight-propagation time

## Staged hints

<details><summary>Hint 1 — question 1</summary>

Compare a loop of `curl` (new connection each time) against a single client
reusing a connection — `curl` with multiple URLs in one invocation, or `ab -k`.
If the distribution differs, splitting is happening at a level that keepalive
affects, and that has real consequences for a canary: a small number of
long-lived clients can produce a distribution nothing like the configured
weights.
</details>

<details><summary>Hint 2 — question 4</summary>

`weight: 0` means the backend receives no traffic but **remains a valid
backendRef**. Removing it entirely is different: if it was the only backend, the
route now has none and returns 500. The specification defines `weight: 0` as
valid and meaningful, which matters when a controller is manipulating weights
automatically.
</details>

## Why this lab exists

When a canary in module 11 promotes something it should not have, the cause is
either the metric, the threshold, or the timing. This lab gives you the timing
baseline, without which you cannot tell the three apart.
