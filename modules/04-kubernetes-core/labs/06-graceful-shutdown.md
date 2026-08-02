# Lab 04.06 — Grace periods and dropped requests

**EXTEND · 30 min**

> Skip if behind schedule. Module 11's canary timing depends on understanding
> this, so return to it before then.

## Context

Module 01 taught your application to handle `SIGTERM`. This lab shows that
handling `SIGTERM` correctly is **not sufficient** to avoid dropping requests
during a rollout.

## The problem

### Part 1 — measure the drop

```bash
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do
    wget -qO- -T2 http://pulse-api:8080/api/checks >/dev/null 2>&1 \
      && echo ok || echo FAIL
    sleep 0.02
  done'

kubectl rollout restart deployment/pulse-api -n pulse
kubectl rollout status deployment/pulse-api -n pulse
kubectl logs load -n pulse | sort | uniq -c
```

Record the failure count with probes already correct from lab 02. There will
still be some. That residue is what this lab is about.

### Part 2 — understand the race

Two things happen when a pod is deleted, **concurrently and unordered**:

| Path | Steps |
|---|---|
| Termination | kubelet → `preStop` → `SIGTERM` → grace period → `SIGKILL` |
| Deregistration | API server → endpoints controller → EndpointSlice → every kube-proxy on every node |

The second path is a distributed propagation. It takes time. The pod keeps
receiving new connections throughout.

Prove it: watch the EndpointSlice while deleting a pod.

```bash
kubectl get endpointslice -n pulse -w &
kubectl delete pod <one-pulse-api-pod> -n pulse
```

Measure the delay between the delete and the endpoint disappearing.

### Part 3 — fix it

Add:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sleep", "5"]
```

Re-run part 1. Record the new failure count.

### Part 4 — the numbers that must agree

Three values have to be consistent, and getting them wrong in either direction
causes a different problem:

```
preStop sleep  +  application drain time  <  terminationGracePeriodSeconds
```

Answer in `NOTAS.md`:

1. What happens if `terminationGracePeriodSeconds` is shorter than the sum?
2. What happens if `preStop` is longer than needed?
3. `pulse-api` waits up to 10s in `srv.Shutdown`. With `preStop: 5`, what is the
   minimum safe grace period, and what would you actually set?

## Expected outcome

Failure counts before and after `preStop`, the measured endpoint propagation
delay, and the three values reconciled with an explanation.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

`SIGKILL` arrives mid-drain. In-flight requests are severed. The pod disappears
while still holding connections, and clients see resets rather than clean
responses — worse than a 503, because a reset is not retryable in the same way.
</details>

<details><summary>Hint 2 — question 2</summary>

Every rollout takes longer, multiplied by every pod. With `maxSurge: 1` and 20
replicas, an extra 5s per pod is nearly two minutes added to each deploy. It also
lengthens the window in which a canary sits at a given traffic weight, which
module 11 cares about a great deal.
</details>

## Cleanup

```bash
kubectl delete pod load -n pulse --ignore-not-found
```
