# Lab 11.01 — From Deployment to Rollout

**CORE · 45 min**

## Context

Argo Rollouts replaces the Deployment controller for `pulse-api`. The mechanics
are straightforward; the interesting part is what changes about your other
tooling when the object type changes.

## The problem

### Part 1 — convert

Turn the `pulse-api` Deployment into a `Rollout` with a canary strategy using
Gateway API for traffic splitting — the `HTTPRoute` from module 05, not replica
counts.

```yaml
strategy:
  canary:
    trafficRouting:
      plugins:
        argoproj-labs/gatewayAPI:
          httpRoute: pulse-api
          namespace: pulse
    steps:
      - setWeight: 10
      - pause: { duration: 2m }
      - setWeight: 50
      - pause: { duration: 2m }
```

Analysis comes in lab 02. Get the traffic mechanics right first.

1. What happened to your Deployment? Is it still there?
2. What does `kubectl get all -n pulse` show now?
3. Which of your existing tooling broke? Check: the module 09 deploy gate, Argo
   CD's health assessment, your HPA, the `k8s` group in `verify.sh`.

Question 3 is the real content. Changing the workload type has consequences all
over.

### Part 2 — watch a rollout

```bash
kubectl argo rollouts get rollout pulse-api -n pulse --watch
```

In another terminal, run traffic and record the split at each step:

```bash
for i in $(seq 300); do
  curl -s -H 'Host: pulse.local' localhost:8080/api/version
done | sort | uniq -c
```

4. Does the observed split match `setWeight`? How close?
5. What does the `HTTPRoute` look like mid-rollout? Inspect it.

### Part 3 — manual control

```bash
kubectl argo rollouts pause pulse-api -n pulse
kubectl argo rollouts promote pulse-api -n pulse
kubectl argo rollouts abort pulse-api -n pulse
kubectl argo rollouts undo pulse-api -n pulse
```

6. Difference between `abort` and `undo`?
7. After `abort`, what state is the Rollout in and what does it take to move on?

### Part 4 — the abort path

Run load during an abort and count failures.

8. How many requests failed? Why?
9. Which module 04 settings determine that number?

If the answer to 8 is not near zero, go back to module 04 lab 06 — `preStop`,
grace period and endpoint propagation are what make a rollback invisible.

## Expected outcome

A working canary by traffic weight, the observed split recorded, a list of what
broke when the object type changed, and a measured abort.

## Verification

```bash
kubectl argo rollouts status pulse-api -n pulse
kubectl get httproute pulse-api -n pulse -o jsonpath='{.spec.rules[0].backendRefs}'
```

## Staged hints

<details><summary>Hint 1 — question 3</summary>

Argo CD may report the Rollout as `Healthy` immediately unless it knows the
resource type — check whether it has a health assessment for it. Your HPA must
target the Rollout via `scaleTargetRef`, not a Deployment. And any script doing
`kubectl rollout status deployment/...` now refers to something that no longer
exists.
</details>

<details><summary>Hint 2 — question 6</summary>

`abort` stops the current rollout and sends all traffic back to stable, but the
Rollout still points at the new revision — it sits `Degraded` until you act.
`undo` changes the desired revision back to the previous one. Abort is "stop
now"; undo is "go back". Confusing them during an incident wastes minutes.
</details>
