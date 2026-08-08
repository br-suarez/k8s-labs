# Module 15 — Jenkins & Ansible: Operate and Migrate

**3 blocks — 1 Jenkins, 2 Ansible.** Requires modules 09 and 13.

The split is deliberate and uneven. Reading an inherited Jenkinsfile when you
already know GitHub Actions is largely a translation exercise: stages, agents,
credentials and artifacts map almost one to one. One block is enough to read
one, operate it, and write the comparison.

**Ansible is not legacy** and gets the other two. It remains the right answer for
everything that is not a container — VMs, network appliances, bare metal, and the
nodes your cluster runs on. Treating it as Jenkins's companion undersells it.

## Why this comes last, and why it is framed as migration

Nobody is building new Jenkins infrastructure in 2026. But a great deal of real
infrastructure runs on it, and the job you get will involve inheriting some. The
valuable skill is not "I know Jenkins" — it is "I can read an inherited
Jenkinsfile, operate it safely, and argue for a migration with evidence."

That framing only works if you already know the modern alternative. You do:
module 09. Doing Jenkins first would teach you the tool without the judgement.

## Objectives

1. Operate Jenkins: pipelines, agents, credentials, and the failure modes of a
   long-lived controller.
2. Write idempotent Ansible that is honest about what it changed.
3. Provision a non-containerised Pulse worker on a VM with Ansible.
4. Produce an evidence-based migration comparison.

## Exit criteria

- [ ] I can read an inherited declarative Jenkinsfile and explain what it does,
      what is unsafe about it, and what it would become in GitHub Actions.
- [ ] I can write a playbook that reports `changed=0` on its second run and
      explain every task that needed work to get there.
- [ ] I can explain why `changed=0` matters beyond tidiness — what an
      always-changing task does to a scheduled run.
- [ ] I can present a migration recommendation with cost, risk and effort, and
      defend the decision to *not* migrate.

## Labs

### Jenkins — 1 block

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) (módulos 14, 13, 06, 09) | CORE | 15 min |
| 01 | [Inherit a Jenkins](./labs/01-inherit-jenkins.md) — read and operate a pipeline you did not write | CORE | 55 min |
| 02 | [**The migration document**](./labs/02-migration-doc.md) — including the case for staying | CORE | 50 min |

### Ansible — 2 blocks

| # | Lab | Level | Time |
|---|---|---|---|
| 03 | [Ansible from zero, and idempotency measured](./labs/03-ansible-zero.md) | CORE | 50 min |
| 04 | [Roles, vault and dynamic inventory](./labs/04-roles-vault.md) | CORE | 50 min |
| 05 | [A worker that is not a container](./labs/05-vm-worker.md) | CORE | 50 min |
| 06 | [**Patch the cluster without breaking it**](./labs/06-patch-nodes.md) | CORE | 50 min |
| 07 | [Push versus reconcile](./labs/07-ansible-vs-operator.md) | EXTEND | 40 min |

## Capstone layer

A `pulse-worker` runs on a VM, provisioned entirely by Ansible, reporting to the
same `pulse-api` and scraped by the same Prometheus. Both CI systems build the
same artifact, which is what makes the comparison in lab 02 evidence rather than
opinion.

## Note

`archive/sre-track/28-ansible-idempotency/` already covers idempotency, including
Ansible silently ignoring a config on a world-writable mount. If your diagnostic
confirms it, skim lab 03 and spend the time on labs 04 and 06 — 06 is where the
genuinely new problem lives: Ansible operating on a live cluster.

## Verification

```bash
ansible-playbook -i inventory site.yml --check    # changed=0
curl -s localhost:8080/api/results | jq '.[] | select(.source=="vm-worker")'
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
