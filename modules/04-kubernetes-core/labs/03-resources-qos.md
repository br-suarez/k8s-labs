# Lab 04.03 — Requests, limits and eviction

**CORE · 45 min**

## Context

Requests and limits are the most consequential two numbers in a manifest and the
ones most often copied from an example. This lab makes you predict behaviour
before observing it.

## The problem

### Part 1 — the three QoS classes

Deploy three variants of a memory-consuming pod:

```bash
# Guaranteed: requests == limits
# Burstable:  requests <  limits
# BestEffort: neither
```

Confirm each classification:

```bash
kubectl get pods -n pulse -o custom-columns=\
NAME:.metadata.name,QOS:.status.qosClass
```

### Part 2 — predict, then evict

**Write your prediction first.** Then create memory pressure on the node and see
which pod dies, in what order.

```bash
kubectl run hog --image=polinux/stress -n pulse --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"hog","image":"polinux/stress",
  "command":["stress","--vm","1","--vm-bytes","3G","--vm-hang","0"]}]}}'

kubectl get events -n pulse --sort-by=.lastTimestamp -w
```

Record: predicted order, actual order, and whether you were right.

### Part 3 — OOMKill vs eviction

These are **not** the same thing and the distinction matters at 3am.

1. Make a container exceed its own memory limit. Observe.
2. Make the node run out of memory with pods below their limits. Observe.

```bash
kubectl get pod <name> -n pulse -o jsonpath='{.status.containerStatuses[0].lastState}'
kubectl describe node | grep -A5 Conditions
```

Answer in `NOTAS.md`: who kills the process in each case, what the pod's status
becomes, and which one you can see in `kubectl get events`.

### Part 4 — CPU throttling without hitting the limit

Set a CPU limit well above the pod's average usage, then generate bursty load.

```bash
kubectl exec -n pulse deploy/pulse-api -- \
  cat /sys/fs/cgroup/cpu.stat | grep throttled
```

Explain why throttling occurs despite average usage being far below the limit.

## Expected outcome

- Three QoS classes demonstrated
- A written prediction versus the actual eviction order
- The OOMKill/eviction distinction, in your own words
- Throttling observed without the limit being reached on average

## Staged hints

<details><summary>Hint 1 — eviction order</summary>

The kubelet ranks by QoS and then by how far each pod exceeds its request.
BestEffort first, then Burstable over its request, Guaranteed last. Crucially: a
Burstable pod **under** its request is fairly safe — the request is a promise the
kubelet tries to honour.
</details>

<details><summary>Hint 2 — part 4</summary>

CFS enforces the quota in 100 ms periods. A process that uses its whole quota in
the first 20 ms of a period is stopped for the remaining 80 ms, even though its
average over a second looks low. This is the strongest argument for omitting CPU
limits and keeping only requests — a position worth being able to defend.
</details>

## Cleanup

```bash
kubectl delete pod hog -n pulse --ignore-not-found
```
