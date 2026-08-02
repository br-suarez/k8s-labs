# Lab 06.02 — Shared storage with NFS

**CORE · 50 min**

## Context

`ReadWriteMany` is the access mode everyone wants and few understand the cost of.
This lab gives Pulse shared storage and then shows you exactly how it fails.

## The problem

### Part 1 — an NFS server in-cluster

Deploy an NFS server as a StatefulSet with its own PVC, plus a StorageClass or a
static PV/PVC pair backed by it.

Mount the resulting `ReadWriteMany` volume in all three `pulse-worker` replicas
at `/artifacts`. Have the worker write probe artifacts there — a response body
snapshot per failed probe is realistic and useful.

Verify genuine sharing:

```bash
kubectl exec -n pulse pulse-worker-0 -- sh -c 'echo hello > /artifacts/test'
kubectl exec -n pulse pulse-worker-1 -- cat /artifacts/test
```

### Part 2 — concurrent writes

Have all three replicas write to the **same file** simultaneously:

```bash
for i in 0 1 2; do
  kubectl exec -n pulse pulse-worker-$i -- sh -c \
    'for n in $(seq 500); do echo "worker-'$i' line $n" >> /artifacts/shared.log; done' &
done
wait

kubectl exec -n pulse pulse-worker-0 -- wc -l /artifacts/shared.log
```

Expected: 1500 lines. Count what you actually get, and examine whether any lines
are interleaved or corrupted.

Answer in `NOTAS.md`:

1. Did you lose lines? Are any mangled?
2. Does NFS guarantee atomic appends? Under what conditions?
3. What would you use instead for a workload that genuinely needs shared
   concurrent writes?

### Part 3 — kill the server

This is the part that matters.

```bash
kubectl exec -n pulse pulse-worker-0 -- sh -c 'cat /artifacts/shared.log > /dev/null' &
kubectl scale statefulset nfs-server -n pulse --replicas=0
```

Now observe, on the node:

```bash
docker exec <node> ps -eo pid,stat,wchan:30,comm | grep -E 'D|cat'
kubectl exec -n pulse pulse-worker-0 -- ls /artifacts    # will hang
```

4. What process state is it in? Why does `SIGKILL` not work?
5. This is the same state you saw in module 01 lab 02. Which scenario was it?
6. Try `kubectl delete pod pulse-worker-0 --force --grace-period=0`. What
   happens to the Kubernetes object, and what happens to the process on the
   node? Explain why this is dangerous with `ReadWriteMany`.

Bring the server back and confirm recovery:

```bash
kubectl scale statefulset nfs-server -n pulse --replicas=1
```

### Part 4 — hard vs soft

Remount with `soft,timeo=30` and repeat part 3. Record the difference in
behaviour, then write down which you would choose for artifacts and which for
backups, with reasons.

## Expected outcome

Working RWX storage, a documented concurrent-write result, and a first-hand
demonstration of an NFS hang including why `--force` is not the answer.

## Staged hints

<details><summary>Hint 1 — question 4</summary>

State `D`: uninterruptible sleep. The process is blocked inside a kernel syscall
waiting on the network filesystem. Signals — including `SIGKILL` — are only
delivered when the process returns to user space, and it never does. This is why
NFS outages raise load average without consuming CPU.
</details>

<details><summary>Hint 2 — question 6</summary>

`--force` removes the object from the API server without waiting for the kubelet
to confirm cleanup. The pod vanishes from `kubectl` while the process may still
be running on the node with the volume mounted. Kubernetes then schedules a
replacement that mounts the same RWX volume — two writers, one of which nobody is
tracking. That is how `--force` corrupts data.
</details>

## Cleanup

```bash
kubectl scale statefulset nfs-server -n pulse --replicas=1   # leave it running for lab 03
```
