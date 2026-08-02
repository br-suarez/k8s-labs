# Refresher 27: Terraform — Module, Import, and Drift

**Module:** 27 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

A small reusable module, an object adopted into state after being created by
hand, and drift caused two different ways — resolved differently each time.
Kubernetes provider against the local kind cluster, local backend.

```bash
./run-lab.sh
```

Evidence: [`01-import-and-drift.txt`](./evidence/01-import-and-drift.txt).

---

## The module

[`modules/k8s-app/`](./modules/k8s-app/) — ConfigMap, Deployment, Service.

**The namespace is created outside the module, not inside it.** A module that
creates its own namespace cannot be instantiated twice in the same namespace,
and destroying one instance takes the namespace — and everything else living in
it — with it. Ownership of shared containers belongs above the module.

**Validation lives in the module:**

```hcl
validation {
  condition     = var.replicas >= 1 && var.replicas <= 10
  error_message = "replicas must be between 1 and 10."
}
```

Without it, `replicas = -1` fails at *apply* time with an API error. With it, it
fails at *plan* time with a sentence a human wrote.

---

## Import — adopting an object Terraform did not create

The usual reality: something was created by hand, a long time ago, by someone
else. Terraform's view of an object it does not know about is that it must be
created:

```
$ terraform plan
      + data = {
          + "log_level" = "info"
          + "owner"     = "payments-team"
          + "tier"      = "internal"
        }
Plan: 1 to add, 0 to change, 0 to destroy.
```

Applying that would fail — the object already exists. Import binds the live
object to the configuration block instead:

```bash
terraform import kubernetes_config_map_v1.legacy_settings tf-lab/legacy-settings
```

```
Import prepared!
  Prepared kubernetes_config_map_v1 for import
Import successful!
```

```
$ terraform plan
No changes. Your infrastructure matches the configuration.
```

**Import does not write configuration.** The `resource` block has to exist
first, and its arguments have to already match the live object — otherwise the
import succeeds and the very next plan proposes to "fix" the real thing to match
whatever the block happens to say. The workflow is: write the block, import,
then run `plan` and expect **no changes**. A non-empty plan right after an
import means the configuration is wrong, not that the import failed.

---

## Drift 1 — someone scaled the Deployment by hand

The 3am fix that never makes it back into the code:

```
$ kubectl scale deployment checkout -n tf-lab --replicas=5
NAME       DESIRED   READY
checkout   5         5
```

Two commands, same field, opposite answers — because they answer different
questions:

```
# terraform plan -refresh-only   -> "what changed underneath us?"
  # module.checkout.kubernetes_deployment_v1.this has changed
      ~ spec {
          ~ replicas = "2" -> "5"
```

```
# terraform plan                 -> "what will I do about it?"
      ~ spec {
          ~ replicas = "5" -> "2"
Plan: 0 to add, 2 to change, 0 to destroy.
```

`-refresh-only` is the read-only one. It reports drift and explicitly refuses to
propose corrections — the safe command to run on a schedule against production
when the answer to "has anyone touched this?" actually matters.

`terraform apply` then reconciled reality back to the code, and the manual scale
was reverted.

---

## Drift 2 — someone edited a ConfigMap, and the choice matters

```
$ kubectl patch configmap legacy-settings --type merge \
    -p '{"data":{"log_level":"debug","added_by_hand":"true"}}'

{"added_by_hand":"true","log_level":"debug","owner":"payments-team","tier":"internal"}
```

```
  # kubernetes_config_map_v1.legacy_settings has changed
      ~ data = {
          + "added_by_hand" = "true"
          ~ "log_level"     = "info" -> "debug"
```

Two valid and **opposite** responses:

| Command | Effect |
|---------|--------|
| `terraform apply` | **Code wins.** Reverts the manual change. |
| `terraform apply -refresh-only` | **Reality wins.** Records the change in state; the *code* is now out of date. |

The second is the trap. It makes the plan clean without making the
configuration correct — the next engineer reads `main.tf`, believes
`log_level = "info"`, and is wrong. It is the right call when the drift was
intentional and the code is about to be updated to match; it is a landmine
otherwise.

This run took the first option, and the final state converged:

```
{"log_level":"info","owner":"payments-team","tier":"internal"}

No changes. Your infrastructure matches the configuration.
```

---

## Issues encountered

**Provider normalisation noise buries real drift.** The first `-refresh-only`
output was filtered with `tail -25` and the replica change was nowhere in it.
The Kubernetes provider reports `+ annotations = {}`, `+ binary_data = {}`,
`+ node_selector = {}` and a dozen similar empty-collection defaults as
"changes made outside Terraform" on essentially every refresh. The actual
one-line drift was pushed 46 lines down by cosmetic diff. On a real estate of
resources this is how genuine drift goes unnoticed in a wall of output that
everyone has learned to skim.

**`terraform fmt -check` failed the first run.** Misaligned `=` in a `data`
block — invisible while writing, caught immediately by the formatter. It belongs
in CI for the same reason `gofmt` does: alignment arguments are not worth having.

---

## What I re-learned

- **`plan` and `plan -refresh-only` answer different questions and it is worth
  being deliberate about which one you want.** Same field, opposite directions:
  `"2" -> "5"` is *what happened*, `"5" -> "2"` is *what I would do about it*.
  Scheduled drift detection wants the first; a deploy pipeline wants the second.

- **Import binds, it does not generate.** The configuration block has to exist
  and has to already be correct. The real test of an import is that the plan
  immediately afterwards is empty.

- **Accepting drift is a decision with a cost, not a shortcut.**
  `apply -refresh-only` silences the diff and leaves the code lying. It is
  occasionally the right call, but it converts a visible problem into an
  invisible one, and only a follow-up commit closes it.

- **`ignore_changes` is a fork in the road, so the module leaves it commented
  out on purpose.** Adding `ignore_changes = [spec[0].replicas]` would let an
  HPA or an operator own the replica count without fighting Terraform. Leaving
  it off means Terraform owns it and manual scaling is always reverted. Both are
  defensible; what is not defensible is not choosing, because the default
  silently makes the choice on your behalf during an incident.

- **State is the actual product.** Everything in this lab — import, refresh,
  drift — is manipulation of the mapping between configuration and reality.
  Which is also why `*.tfstate` is in [`.gitignore`](./.gitignore): it holds the
  full resolved attributes of every managed resource, including anything
  sensitive the provider read.
