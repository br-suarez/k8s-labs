# Lab 15.05 — A worker that is not a container

**CORE · 50 min**

## Context

The capstone layer for this module: a `pulse-worker` running on a VM, provisioned
entirely by Ansible, reporting to the same `pulse-api` as the containerised ones.

It is a realistic hybrid — the shape most organisations actually have, rather
than the fully-containerised one they describe.

## The problem

### Part 1 — provision it

Extend the role so the VM worker:

1. Runs as a systemd unit with restart policy and resource limits.
2. Authenticates to `pulse-api` the same way the in-cluster workers do.
3. Ships logs somewhere you can query — journald plus a shipper.
4. Exposes its metrics so Prometheus from module 07 can scrape it.

Point 4 is the interesting one: the VM is outside the cluster, so service
discovery does not find it.

5. How does Prometheus discover a target that is not a Kubernetes object? Name
   two mechanisms.

### Part 2 — make it indistinguishable where it matters

```promql
sum by (instance) (rate(pulse_worker_probes_total[5m]))
```

6. Does the VM worker appear alongside the pods?
7. Do your module 07 SLOs cover it? Should they?
8. What label distinguishes it, and did you have to add anything?

### Part 3 — the differences you cannot hide

9. What does the VM worker do differently on failure? Compare against a pod:
   who restarts it, how fast, and what happens if the machine dies?
10. How do you deploy a new version to it? Compare the time and the risk against
    a rolling update.
11. What does the canary from module 11 do about it? (Nothing — and that is
    worth writing down.)

### Part 4 — verify

```bash
ansible-playbook -i inventory site.yml --check
```

12. `changed=0`? If not, which task is not idempotent?

```bash
curl -s localhost:8080/api/results | jq '[.[] | select(.source=="vm-worker")] | length'
```

13. Is it actually doing work?

### Part 5 — the honest comparison

14. What is genuinely worse about the VM worker?
15. What is genuinely better?
16. Under what circumstances would you choose it deliberately?

Question 15 has real answers: no container runtime overhead, direct hardware
access, simpler network path, and it survives a cluster outage — the last one
matters if the worker is what tells you the cluster is down.

## Expected outcome

A VM worker provisioned by Ansible, reporting to the same API and scraped by the
same Prometheus, with a clean `--check` and an honest comparison in three
directions.

## Staged hints

<details><summary>Hint 1 — question 5</summary>

A static scrape config, or file-based service discovery where Ansible writes the
target file as part of provisioning — which keeps the config in the same place as
the machine's configuration. In cloud, the provider's SD mechanism reads
instance tags. The Ansible-writes-the-file approach is the tidiest for a hybrid,
because provisioning and discovery stay in one workflow.
</details>
