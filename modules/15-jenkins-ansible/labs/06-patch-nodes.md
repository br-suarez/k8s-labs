# Lab 15.06 — Patch the cluster without breaking it

**CORE · 50 min.** The most important lab in this module.

## Context

Do the break-fix first. This lab builds the correct playbook, and the point is
not the YAML — it is that a playbook operating on a declarative system has to
verify convergence, not exit codes.

## The problem

### Part 1 — reproduce the damage, deliberately

In a cluster you can afford to break, run the broken playbook from the break-fix
with load flowing.

```bash
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- -T2 http://pulse-api:8080/api/checks >/dev/null 2>&1 \
    && echo ok || echo FAIL; sleep 0.1; done'

ansible-playbook -i inventory patch-nodes-broken.yml
```

1. How long was Pulse unavailable? Count the failures.
2. What did the Ansible recap say?
3. At what moment did the outage become inevitable?

Question 3's answer is the moment the third node was cordoned — before any
update ran.

### Part 2 — one node at a time

Add `serial: 1`. Re-run.

4. Better? Measure the failures again.
5. Is it zero? If not, what is still wrong?

It will not be zero yet, because `--disable-eviction` is still there.

### Part 3 — let the PDBs do their job

Remove `--disable-eviction` and `--force`. Raise the drain timeout.

6. What happens now when a drain would violate a PDB?
7. Does the playbook wait, or fail? Which do you want, and how do you express it?
8. Re-measure. Zero failures?

### Part 4 — verify convergence, not exit codes

The heart of the fix:

```yaml
post_tasks:
  - name: Verify service health before the next node
    command: ./platform/scripts/verify.sh k8s slo
    delegate_to: localhost
    register: health
    until: health.rc == 0
    retries: 10
    delay: 30
    changed_when: false
```

9. Why `post_tasks` and not a regular task?
10. What happens if health never recovers? Is that the behaviour you want?
11. Add `max_fail_percentage: 0`. What does it change?

### Part 5 — the ordering problem

12. `kubectl wait --for=condition=Ready node/...` after the reboot — why is
    "the host answers SSH" not sufficient?
13. What else has to be true before the node can take pods again? Think about
    the kubelet, the CNI, and any DaemonSet that must be running.

### Part 6 — the test

14. Write a check that proves the playbook is safe **without** running a real
    patch cycle. What would you assert?

Question 14 is the same principle as the canary verification in module 11 and the
restore drill in module 06: a safety mechanism that has never been shown to work
is a hypothesis.

## Expected outcome

The outage reproduced and measured, three fixes applied incrementally with
failures counted at each step, zero failures at the end, and a written assertion
that the playbook is safe.

## Staged hints

<details><summary>Hint 1 — question 7</summary>

`kubectl drain` retries until its timeout when eviction is blocked by a PDB. If
the timeout expires it exits non-zero. You want that to **fail the play** — a
drain that cannot complete safely means something is wrong and continuing to the
next node would compound it. `failed_when: drain.rc != 0` with a generous
timeout expresses "wait patiently, then stop".
</details>

<details><summary>Hint 2 — question 13</summary>

The node reports `Ready` only once the kubelet is up and the CNI has initialised.
But `Ready` still does not mean your DaemonSets are running — a node with no
`node-exporter` or no log shipper is serving traffic unobserved. Waiting for the
relevant DaemonSet pods is the thorough version.
</details>
