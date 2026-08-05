# Lab 09.05 — The gate that catches a green liar

**CORE · 50 min**

## Context

You built this once in `archive/sre-track/30-cicd-deploy-gate/`. Doing it again
is deliberate: this time it runs in real CI against a real registry, and the
interesting failure is the opposite one.

## The problem

### Part 1 — the release that lies

Deploy a build that reports perfect health and fails 19% of requests:

```bash
kubectl set env deployment/pulse-api -n pulse INJECT_ERROR_RATE=0.19
kubectl get pods -n pulse
# READY 1/1, RESTARTS 0, everything green
```

Confirm that a naive gate passes it:

```bash
kubectl rollout status deployment/pulse-api -n pulse   # succeeds
kubectl wait --for=condition=Available deployment/pulse-api -n pulse  # succeeds
```

1. Why do both of those pass?
2. What are they actually measuring?

### Part 2 — a gate that works

Write `scripts/deploy-gate.sh`, called from the workflow after deploy. It must:

1. Generate representative traffic — the real paths, not `/healthz`.
2. Measure error rate and p99 against the module 07 SLO.
3. Run for a window long enough to be statistically meaningful. **Justify the
   number** — how many requests do you need to distinguish 19% from 0% with
   confidence?
4. Fail with a message naming the metric, the observed value and the threshold.
5. Roll back automatically on failure.
6. Pass `shellcheck`.

Requirement 3 is the one people skip. A gate that samples 20 requests cannot tell
1% from 5%.

### Part 3 — the opposite failure

Now make your gate reject a **healthy** release. Then answer:

7. What caused the false negative? Threshold too tight, window too short, or
   traffic unrepresentative?
8. Which is worse operationally — a gate that passes bad releases, or one that
   blocks good ones? Argue it.

Question 8 has no clean answer and that is why it is asked. A gate that
false-negatives gets disabled by the team within two weeks, and then you have no
gate at all — which makes it arguably worse than the permissive one.

### Part 4 — wire it in

Add it to the workflow between deploy and success. Prove both directions:

```bash
# Should block
kubectl set env deployment/pulse-api -n pulse INJECT_ERROR_RATE=0.19
gh workflow run ci.yml && gh run watch

# Should pass
kubectl set env deployment/pulse-api -n pulse INJECT_ERROR_RATE-
gh workflow run ci.yml && gh run watch
```

## Expected outcome

A gate that blocks the 19% release, a documented false negative and its cause,
a justified sample size, and both directions demonstrated in real CI.

## Staged hints

<details><summary>Hint 1 — sample size</summary>

To distinguish a 19% error rate from 0% you need very few requests. To
distinguish 1% from 0.1% you need thousands. Work out roughly what your SLO
implies: if the threshold is 1% and you send 100 requests, a single unlucky
failure trips it. That is where false negatives come from, and it is arithmetic,
not bad luck.
</details>

<details><summary>Hint 2 — rollback</summary>

`kubectl rollout undo` is the quick path, but it reverts to the previous
ReplicaSet, which may not be the previous *release* if several deploys happened.
Rolling back to a known digest is unambiguous. Note this problem — module 10
solves it properly, because in GitOps the rollback is a git revert.
</details>
