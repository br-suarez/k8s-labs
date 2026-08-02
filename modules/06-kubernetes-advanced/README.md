# Module 06 — Kubernetes Advanced: State, Storage, HA

**5 blocks.** Requires module 04.

The reference repo's "Part II" — TLS, HA, Helm, backup, storage — is an index
with no content behind it. This module is that content, built from scratch.

## Objectives

1. Run stateful workloads correctly: StatefulSets, PVCs, ordered lifecycle.
2. Provide shared storage across pods with NFS and know its failure modes.
3. Survive node loss: PDBs, anti-affinity, and a real control-plane quorum.
4. Perform a backup **and a restore** — a backup you have never restored is a
   hypothesis, not a backup.

## Exit criteria

- [ ] I can convert a Deployment with a PVC into a correct StatefulSet and
      explain what changed and why it was necessary.
- [ ] I can restore Pulse's database from backup into a fresh cluster, timed,
      and state the RPO and RTO I actually achieved.
- [ ] Given a pod stuck `Terminating`, I can name the four common causes and
      diagnose which applies.
- [ ] I can explain why an NFS-backed volume can hang a pod so it cannot be
      killed, and what that has to do with the `D` process state from module 01.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 04–05) | CORE | 15 min |
| 01 | Postgres as a StatefulSet: stable identity, ordered startup, volumeClaimTemplates | CORE | 55 min |
| 02 | NFS server in-cluster; shared `ReadWriteMany` volume for probe artifacts | CORE | 50 min |
| 03 | **Backup and restore drill** — destroy the database, restore it, measure RPO/RTO | CORE | 55 min |
| 04 | PDBs and anti-affinity: drain a node with Pulse running and keep serving | CORE | 45 min |
| 05 | HA control plane (`ha` profile): kill one etcd member and survive; kill two and understand why you did not | EXTEND | 50 min |
| 06 | The pod that will not die: NFS hang, finalizers, and `--force` (and why `--force` is usually wrong) | EXTEND | 40 min |

> Lab 05 uses the `ha` cluster profile (~6 GiB). Tear it down immediately after.
> If your host cannot afford it, read the lab, write down what you expect, and
> mark it as deferred in `TRACKER.md` — do not skip it silently.

## Capstone layer

Pulse becomes stateful and survivable: Postgres in a StatefulSet, shared NFS
storage, PDBs on both services, and `platform/scripts/restore-drill.sh` that
proves a restore works end to end.

## Verification

```bash
./platform/scripts/restore-drill.sh
./platform/scripts/verify.sh k8s storage
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
