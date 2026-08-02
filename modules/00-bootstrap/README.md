# Module 00 — Bootstrap & Environment

**2 blocks.** No prerequisites.

The only module whose deliverable is an environment rather than a capability.
Everything after this assumes it is done and reproducible.

## Objectives

1. A reproducible toolchain at pinned versions, installed by a script you have
   read and can explain line by line.
2. A verification harness that answers "is my environment correct?" with an exit
   code, not a feeling.
3. WSL memory configured so that module 07 does not die of OOM.

## Exit criteria

- [ ] `./scripts/verify-setup.sh` exits 0.
- [ ] I can destroy every installed tool and rebuild the environment in under 15
      minutes using nothing but this repository.
- [ ] `free -h` reports at least 10 GiB available to WSL, or `TRACKER.md` records
      why it cannot and which cluster profile I will use instead.
- [ ] I can explain why this track uses kind rather than k3d, and name the
      situation in which I would choose k3d instead.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 01 | [Read before you run](./labs/01-read-the-bootstrap.md) | CORE | 30 min |
| 02 | [Memory and the WSL ceiling](./labs/02-wsl-memory.md) | CORE | 30 min |
| 03 | [First cluster, then destroy it](./labs/03-first-cluster.md) | CORE | 40 min |
| 04 | [Extend the harness](./labs/04-extend-harness.md) | EXTEND | 20 min |

## Capstone layer

None yet — module 01 adds the first. What you produce here is the ground the
platform stands on.

## Verification

```bash
./scripts/verify-setup.sh
```

---

## Problem → Solution → What I Learned

> Fill this in when you close the module, written for someone who has never seen
> this repository.

### Problem

### Solution

### What I Learned
