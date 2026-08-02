# Lab 06.06 — The pod that will not die

**EXTEND · 40 min**

> Skip if behind schedule. Worth returning to before module 16 — a stuck
> `Terminating` pod is a Game Day scenario waiting to happen.

## Context

Four different causes produce the identical symptom. Reaching for `--force`
without knowing which one you have is how a stuck pod becomes corrupted data.

## The problem

Reproduce each cause, diagnose it from symptoms alone, and resolve it **without**
`--force` where possible.

### Cause 1 — a finalizer nobody resolves

```bash
kubectl run stuck-1 --image=nginx:alpine -n pulse
kubectl patch pod stuck-1 -n pulse -p \
  '{"metadata":{"finalizers":["example.com/nonexistent"]}}'
kubectl delete pod stuck-1 -n pulse --timeout=20s
```

Diagnose, then clear it correctly. Answer: what is a finalizer *for*, and what
would you break by removing a real one?

### Cause 2 — SIGTERM ignored, long grace period

Deploy a pod that traps and ignores `SIGTERM`, with
`terminationGracePeriodSeconds: 300`. Delete it and observe.

How do you tell this apart from cause 1 in under 30 seconds?

### Cause 3 — a volume that will not unmount

Use the NFS setup from lab 02: start a read, kill the NFS server, delete the pod.

This is the one where `--force` is actively dangerous. Explain precisely why.

### Cause 4 — the kubelet is not responding

```bash
docker exec pulse-worker systemctl stop kubelet
kubectl delete pod <pod-on-that-node> -n pulse
```

What does the node status become, and how long until Kubernetes acts on its own?
Restart the kubelet afterwards.

## The deliverable

A decision tree in `NOTAS.md`:

```
Pod stuck Terminating
├─ metadata.finalizers non-empty?      → cause 1 · resolve or remove the finalizer
├─ node NotReady?                      → cause 4 · fix the kubelet, do not force
├─ process in D state on the node?     → cause 3 · fix storage FIRST, never force
└─ otherwise                           → cause 2 · check grace period and signal handling
```

Expand each branch with the exact command that confirms it and the correct
resolution. Then add: **when is `--force` actually correct?**

## Expected outcome

Four causes reproduced and diagnosed, a usable decision tree, and a written
answer on when forcing is legitimate.

## Staged hints

<details><summary>Hint 1 — telling them apart fast</summary>

```bash
kubectl get pod <name> -o jsonpath='{.metadata.finalizers}{"\n"}{.metadata.deletionGracePeriodSeconds}{"\n"}'
kubectl get node
```

Three values, three seconds, and you have eliminated two of the four branches.
</details>

<details><summary>Hint 2 — when --force is correct</summary>

When the node is confirmed gone — genuinely destroyed, not merely unreachable —
and you have established that no process can still be writing to shared storage.
"Unreachable" is not "gone": a partitioned node may be running happily with your
volume mounted. That distinction is the whole answer.
</details>

## Cleanup

```bash
kubectl delete pod stuck-1 -n pulse --ignore-not-found
docker exec pulse-worker systemctl start kubelet
```
