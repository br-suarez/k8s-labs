# Lab 06.04 — Survive a node drain

**CORE · 45 min**

## Context

Node maintenance is routine. Whether it is invisible to users depends on
decisions you make before it happens.

## The problem

### Part 1 — drain without protection

```bash
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- -T2 http://pulse-api:8080/api/checks >/dev/null 2>&1 \
    && echo ok || echo FAIL; sleep 0.05; done'

kubectl drain pulse-worker --ignore-daemonsets --delete-emptydir-data
kubectl logs load -n pulse | sort | uniq -c
```

Record the failure count. Then `kubectl uncordon pulse-worker`.

### Part 2 — spread the replicas

If all three `pulse-api` pods are on one node, no PDB can save you. Add
anti-affinity so they spread.

Two options with different semantics:

```yaml
# A: hard requirement
requiredDuringSchedulingIgnoredDuringExecution

# B: preference
preferredDuringSchedulingIgnoredDuringExecution
```

Implement both in turn and answer:

1. With `required` on a 2-node cluster and 3 replicas, what happens to the third
   pod?
2. Which would you use in production, and what does the other one cost you?
3. What does `IgnoredDuringExecution` mean — what happens if the topology
   changes after scheduling?

Consider `topologySpreadConstraints` as a third option and explain what it gives
you that anti-affinity does not.

### Part 3 — the PDB

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
```

Choose `minAvailable` or `maxUnavailable` deliberately. Then re-run part 1 and
record the new failure count.

### Part 4 — break the PDB on purpose

Set `minAvailable` equal to the replica count. Try to drain.

4. What happens? How long does it wait?
5. Why is this worse than having no PDB at all?
6. With `replicas: 1`, what is the only PDB that permits a drain, and what does
   that tell you about single-replica services?

## Expected outcome

Failure counts before and after, both anti-affinity modes tested, and a
deliberately deadlocked PDB with an explanation.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

The third pod stays `Pending` forever: the hard anti-affinity rule cannot be
satisfied. Your Deployment reports 2/3 and never recovers, and the cause is not
resources — `describe` names the anti-affinity predicate. Easy to cause by
accident when a cluster shrinks.
</details>

<details><summary>Hint 2 — question 6</summary>

Only `maxUnavailable: 1` (equivalently `minAvailable: 0`) allows the drain, and
it permits taking down your only replica — so the PDB protects nothing. A
single-replica service cannot be both highly available and drainable. Say that
out loud to whoever owns the service; it is a capacity decision, not a
configuration one.
</details>

## Cleanup

```bash
kubectl uncordon pulse-worker
kubectl delete pod load -n pulse --ignore-not-found
```
