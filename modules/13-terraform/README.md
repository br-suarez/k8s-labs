# Module 13 — Terraform

**5 blocks** (3 if you pass the diagnostic). Requires module 01.

Deliberately **before** the cloud module. You do not learn a cloud by clicking,
and everything created in module 14 must be destroyable by one command — which is
what keeps that module inside budget.

## Objectives

1. Write reusable modules with real interfaces, not copied directories.
2. Manage state deliberately: remote backends, locking, and what to do when it
   goes wrong.
3. Diagnose drift and distinguish the two directions it can point.
4. Adopt existing infrastructure with `import` without destroying it.

## Exit criteria

- [ ] I can write a module with sensible variables, outputs and validation from
      scratch, and consume it across two environments.
- [ ] Given drift, I can determine whether reality or the configuration is wrong
      and explain why `plan` and `plan -refresh-only` can point in opposite
      directions on the same field.
- [ ] I can import an existing resource and reach a clean plan.
- [ ] I can explain state locking, and describe a safe recovery from a stuck lock
      — including how to tell a stuck lock from an in-progress apply.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) (módulos 09, 12, 03) | CORE | 15 min |
| 01 | [Fundamentals, without touching a cloud](./labs/01-fundamentals.md) — Terraform v1.15.8 | CORE | 40 min |
| 02 | [A module with a real interface](./labs/02-modules.md) | CORE | 50 min |
| 03 | [The platform as code](./labs/03-provision-platform.md) — and the Terraform/Argo boundary | CORE | 50 min |
| 04 | [Locks, and a stuck one](./labs/04-state-locking.md) | CORE | 45 min |
| 05 | [**Drift in two directions**](./labs/05-drift.md) on the same field | CORE | 45 min |
| 06 | [Adopt what already exists](./labs/06-import.md) | CORE | 40 min |
| 07 | [Workspaces or directories](./labs/07-workspaces.md) | EXTEND | 45 min |
| 08 | [Assertions on the plan, before apply](./labs/08-policy-checks.md) | EXTEND | 40 min |

## Capstone layer

The whole local platform is provisioned by `terraform apply` from nothing, and
removed by `terraform destroy` leaving nothing. That property is the
precondition for module 14 staying inside budget.

## Note

`archive/sre-track/27-terraform-import-drift/` covers import and drift already.
If your diagnostic confirms it, skip labs 05 and 06 and spend the time on 07 and
08, which are genuinely new — and on making the module interfaces good enough
that module 14 only has to change a provider.

## Verification

```bash
terraform plan -detailed-exitcode   # exit 0 = no drift
./platform/scripts/verify.sh iac
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
