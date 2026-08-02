# Lab 06.01 — Postgres as a StatefulSet

**CORE · 55 min**

## Context

Pulse has been storing results in memory since module 01. Time to give it real
state, and to meet the constraints that come with it.

## The problem

### Part 1 — the wrong way first

Deploy Postgres as a plain Deployment with `replicas: 2` and a single PVC.

```bash
kubectl get pods -n pulse -w
```

The second pod never starts. Diagnose it properly — do not just read the answer
here. What does `describe` say, and which access mode is responsible?

Record it in `NOTAS.md`. This is the failure that motivates StatefulSets.

### Part 2 — the right way

Write a StatefulSet with:

1. A headless Service for stable per-pod DNS.
2. `volumeClaimTemplates` so each replica gets its own PVC.
3. `ReadWriteOncePod` on the claim — not `ReadWriteOnce`. Be able to explain the
   difference.
4. A readiness probe using `pg_isready`, not a TCP check.
5. `podManagementPolicy` chosen deliberately — decide between `OrderedReady` and
   `Parallel` and write down why.

Verify stable identity:

```bash
kubectl get pods -n pulse -l app=postgres
kubectl exec -n pulse postgres-0 -- hostname -f
kubectl delete pod postgres-0 -n pulse
# same name, same PVC, same DNS after it returns
kubectl get pvc -n pulse
```

### Part 3 — connect Pulse to it

Replace the in-memory store in `pulse-api` with Postgres. The code change is
small; the interesting part is everything around it:

1. Credentials from a Secret, never in the image.
2. A connection pool with bounded size — decide the number and justify it
   against Postgres's `max_connections`.
3. Readiness that reflects **database reachability**, so a pod with a dead
   database leaves the Service.
4. Schema migration on startup, exactly once, safe with 3 replicas starting
   simultaneously.

Point 4 is the interesting one. Three replicas starting at once will all try to
migrate.

## Expected outcome

Pulse persists results across a full restart:

```bash
curl -XPOST .../api/checks -d '{"url":"https://example.com"}'
kubectl delete pod -n pulse -l app=pulse-api
# after rollout, the check is still there
curl .../api/checks
```

## Staged hints

<details><summary>Hint 1 — part 1</summary>

`ReadWriteOnce` binds the volume to a **node**, not a pod. If both replicas land
on the same node, both mount it — which is worse than failing. If they land on
different nodes, the second stays `Pending` with a volume node affinity conflict.
Both outcomes are bad, in different ways.
</details>

<details><summary>Hint 2 — part 3, point 4</summary>

Options: an init container that runs migrations (still races across replicas), a
Kubernetes Job with a sync wave (module 10 formalises this), or an advisory lock
in Postgres itself — `pg_advisory_lock` — so whichever replica gets there first
migrates and the others wait. The last one needs no orchestration and is the most
robust. Explain your choice.
</details>

## Note

Keep this cluster. Labs 02 and 03 build on it directly.
