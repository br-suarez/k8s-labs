# Module 15 — Jenkins & Ansible: Operate and Migrate

**4 blocks.** Requires modules 09 and 13.

Neither tool has any coverage in the reference repos — Ansible appears as a
three-line file. Both are built from scratch here, from beginner to
mid-advanced, so someone starting cold can follow this module and be productive.

## Why this comes last, and why it is framed as migration

Nobody is building new Jenkins infrastructure in 2026. But a great deal of real
infrastructure runs on it, and the job you get will involve inheriting some. The
valuable skill is not "I know Jenkins" — it is "I can read an inherited
Jenkinsfile, operate it safely, and argue for a migration with evidence."

That framing only works if you already know the modern alternative. You do:
module 09. Doing Jenkins first would teach you the tool without the judgement.

The same applies to Ansible, with one difference: Ansible is not legacy. It
remains the right answer for configuring things that are not containers — VMs,
network appliances, bare metal, and the machines that run your Kubernetes nodes.

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

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 13–14) | CORE | 15 min |
| 01 | Jenkins from zero: controller, agent, first pipeline | CORE | 45 min |
| 02 | Declarative Jenkinsfile replicating the module 09 pipeline exactly | CORE | 50 min |
| 03 | Jenkins credentials and the ways they leak into build logs | CORE | 40 min |
| 04 | Ansible from zero: inventory, playbook, roles, idempotency | CORE | 50 min |
| 05 | Provision a VM-based `pulse-worker` with Ansible; `--check` must be clean | CORE | 50 min |
| 06 | **The migration document**: Jenkins vs Actions with real numbers, and the case for staying | CORE | 45 min |
| 07 | Ansible against the Kubernetes nodes: patching without breaking the cluster | EXTEND | 40 min |

## Capstone layer

A legacy `pulse-worker` runs on a VM, provisioned entirely by Ansible, reporting
to the same `pulse-api`. Both CI systems build the same artifact, which is what
makes the comparison in lab 06 evidence rather than opinion.

## Note

`archive/sre-track/28-ansible-idempotency/` already covers idempotency, including
Ansible silently ignoring a config on a world-writable mount. If your diagnostic
confirms it, compress labs 04–05 into one and spend the time on lab 07, which is
the harder and more useful scenario.

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
