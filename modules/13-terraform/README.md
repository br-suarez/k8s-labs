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
| 00 | Repaso (módulos 11–12) | CORE | 15 min |
| 01 | Terraform (v1.15.8) fundamentals against a local provider; no cloud yet | CORE | 40 min |
| 02 | A real module: variables with validation, outputs, versioned | CORE | 50 min |
| 03 | Provision the kind cluster and Pulse's platform resources as code | CORE | 50 min |
| 04 | Remote state and locking; deliberately create a stuck lock and recover | CORE | 45 min |
| 05 | **Drift in two directions** on the same field | CORE | 45 min |
| 06 | Import a hand-created resource to a clean plan | CORE | 40 min |
| 07 | Workspaces vs directory-per-environment: implement both, argue for one | EXTEND | 45 min |
| 08 | Policy checks on the plan JSON — assertions before apply | EXTEND | 40 min |

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
