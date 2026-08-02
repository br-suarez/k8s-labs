# Lab 06.05 — Quorum, and why it is odd numbers

**EXTEND · 50 min**

> Uses the `ha` cluster profile, roughly 6 GiB. **Tear it down immediately
> after.** If your host cannot afford it, read the lab, write down what you
> expect to happen, and mark it deferred in `TRACKER.md` — do not skip silently.

## Context

You can recite "etcd needs quorum". This lab makes you watch a cluster stay up
with one member down and stop with two, and understand the arithmetic.

## The problem

```bash
kind delete cluster --name pulse           # free the memory first
kind create cluster --config platform/deploy/clusters/ha.yaml
```

### Part 1 — inspect the ring

```bash
docker exec pulse-ha-control-plane etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list -w table

# ... endpoint status -w table
```

Identify the leader. Record `RAFT TERM` and `RAFT INDEX`.

### Part 2 — lose one

```bash
docker stop pulse-ha-control-plane2

kubectl get nodes
kubectl create deployment quorum-test --image=nginx:alpine
kubectl get deployment quorum-test
```

1. Did writes still work?
2. Did the leader change? What happened to `RAFT TERM`?
3. How long was the API server unavailable, if at all?

### Part 3 — lose two

```bash
docker stop pulse-ha-control-plane3
kubectl get nodes
kubectl create deployment quorum-test-2 --image=nginx:alpine
```

4. What is the exact error? Read it carefully — it names the condition.
5. Do **reads** still work? Try `kubectl get pods`. Explain what you observe.
6. The surviving member is running and healthy. Why does it refuse writes rather
   than serving alone?

### Part 4 — recover and reason

Bring them back one at a time, observing when writes resume.

Then answer in `NOTAS.md`:

7. Why is a 2-member etcd cluster **worse** than a 1-member cluster?
8. Fill in the table:

| Members | Quorum | Failures tolerated |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |

9. Given row 4, why does anyone run 5 rather than 3?

## Expected outcome

Observed behaviour at each failure level, the completed table, and an
explanation of the even-number problem in your own words.

## Staged hints

<details><summary>Hint 1 — question 6</summary>

Because a single member cannot distinguish "the other two are down" from "I am
the one partitioned away from a majority that is still serving". Refusing writes
without a majority is what prevents two halves of a split cluster both accepting
conflicting writes. Availability is deliberately traded for consistency — etcd is
CP in CAP terms, and this is that choice made visible.
</details>

<details><summary>Hint 2 — question 5</summary>

Reads may succeed from the local cache depending on how they are served. Linearizable
reads go through the Raft log and fail; stale reads can be served locally. That
distinction — that "the cluster is up" depends on which read you mean — is worth
being precise about.
</details>

## Cleanup — do not skip

```bash
kind delete cluster --name pulse-ha
kind create cluster --config platform/deploy/clusters/standard.yaml
```
