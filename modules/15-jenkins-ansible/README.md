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
### Jenkins — 1 block

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 13–14) | CORE | 15 min |
| 01 | Inherit a Jenkins: stand up a controller and an agent, then read and operate a Jenkinsfile you did not write. Find the two places its credentials leak into build logs | CORE | 55 min |
| 02 | **The migration document**: the module 09 pipeline and this one, side by side, with real numbers — and the case for *not* migrating | CORE | 50 min |

### Ansible — 2 blocks

| # | Lab | Level | Time |
|---|---|---|---|
| 03 | From zero: inventory, playbook, modules, and idempotency measured (`changed=0` on the second run, and every task that had to be rewritten to get there) | CORE | 50 min |
| 04 | Roles, `ansible-vault`, and dynamic inventory against a real source | CORE | 50 min |
| 05 | Provision a VM-based `pulse-worker`; `--check` must be clean and the service must report to the same `pulse-api` | CORE | 50 min |
| 06 | Patch the Kubernetes nodes without breaking the cluster: cordon, drain, patch, uncordon — respecting the PDBs from module 06 | CORE | 50 min |
| 07 | Ansible vs a Kubernetes operator for the same task: when does declarative config management stop being the right tool? | EXTEND | 40 min |

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
