# Lab 23: Observability as Code — Terraform + Datadog

**Module:** 23 — Observability with Terraform + Datadog (SRE Track)
**Date:** 2026-08-02
**Stack:** Terraform 1.9, DataDog/datadog provider 3.x

---

## Scope — read this first

**There is no `apply` in this lab, and no Datadog account behind it.** What runs
is `init`, `fmt -check`, `validate`, `plan`, and policy assertions against the
plan's JSON. No dashboard was created, no monitor exists in Datadog, and nothing
here should be read as "this was deployed".

That is a real constraint, and it happens to leave the genuinely portable part
intact: on a Datadog-managed estate, everything below is what CI runs on every
pull request, before anyone has permission to touch production.

```bash
./run-lab.sh
```

Evidence: [`01-validate-and-plan.txt`](./evidence/01-validate-and-plan.txt).

Offline planning works because of one provider argument:

```hcl
provider "datadog" {
  validate = var.datadog_validate   # false skips the credential check
}
```

It is a variable, not a hardcoded `false`, so a real environment leaves it at
the default and fails fast on bad credentials rather than producing a plan it
cannot apply.

---

## What the configuration builds

```
$ terraform show -json tfplan | jq '.resource_changes[]...'
  CREATE  datadog_service_level_objective  availability
  CREATE  datadog_service_level_objective  latency
  CREATE  datadog_monitor                  availability_fast_burn      (14.4x, page)
  CREATE  datadog_monitor                  availability_slow_burn      (6x,    page)
  CREATE  datadog_monitor                  availability_budget_drain   (3x,    ticket)
  CREATE  datadog_monitor                  latency_fast_burn           (14.4x, page)
  CREATE  datadog_dashboard                service_slo
```

The same SLO model as [module 20](../20-slo-error-budgets/README.md), expressed
against Datadog primitives instead of Prometheus rules — 99.5% availability,
99% of requests under 300ms, and multi-window burn-rate alerting.

### One source of truth for the numbers

The objective is a variable; the budget and every threshold are **derived**:

```hcl
availability_error_budget = (100 - var.availability_slo_target) / 100
fast_burn_rate            = 14.4
```

Changing `availability_slo_target` from 99.5 to 99.9 moves the SLO, both
availability monitors, the ticket monitor and the dashboard's threshold markers
together. Hand-written thresholds are how the alert and the dashboard end up
disagreeing about what "too many errors" means — which turns an incident into an
argument about which number is right.

### Monitors are burn-rate, not thresholds

```hcl
type  = "slo alert"
query = <<-EOT
  burn_rate("${datadog_service_level_objective.availability.id}")
    .over("7d").long_window("1h").short_window("5m") > 14.4
EOT
```

Datadog implements the long/short window logic natively — the same design
proven end to end in module 20, where the short window resolved the alert
**8.3 minutes before** the long window would have.

Severity is encoded in behaviour, not just labels:

| Monitor | priority | `renotify_interval` |
|---------|----------|---------------------|
| fast burn 14.4x | 1 | 30 min |
| slow burn 6x | 2 | 60 min |
| budget drain 3x | 4 | **0 — never renotifies** |

A ticket-severity alert that nags is a page with extra steps.

`notify_no_data = false` on all of them: a service receiving no traffic has not
failed, and paging on absent data trains people to ignore the alert.

---

## What the plan can and cannot verify

`terraform show -json` is what a policy engine (OPA, Conftest, Sentinel) reads.
Reviewing a plan by eye does not scale; asserting on its JSON does:

```
  monitors planned:            4
  every monitor tagged:        PASS
  every monitor has a message: PASS
  page-severity have renotify: PASS
```

All of that ran with no Datadog credentials at all.

### The limit, found by hitting it

The first version of this script tried to print each monitor's final query and
crashed:

```
jq: error: null (null) cannot be matched, as it is not a string
```

The query is `null` in the plan. Every burn-rate query interpolates
`datadog_service_level_objective.availability.id`, and that id does not exist
until the SLO is created — so Terraform marks the whole attribute unknown:

```
  availability_fast_burn
      query in .after         : null (unknown at plan time)
      query in .after_unknown : true
      priority (known)        : 1
```

**A plan-time policy gate cannot assert on a value that depends on a
not-yet-created resource.** Checks must target attributes fully determined by
the configuration — tags, priority, renotify, message — or move to a post-apply
test. Writing a rule like "every monitor query must include a short_window" and
watching it pass because the field was `null` would be worse than having no rule
at all.

---

## Issues encountered

**Guessed a block name instead of reading the schema.** The SLO dashboard widget
is `service_level_objective_definition`, not `slo_definition`. `validate` caught
it, and the fastest authoritative answer was not the docs:

```bash
terraform providers schema -json \
  | jq '.provider_schemas["registry.terraform.io/datadog/datadog"]
        .resource_schemas.datadog_dashboard.block.block_types.widget.block.block_types | keys[]'
```

That prints the exact block names and their required attributes for the provider
version actually pinned in `versions.tf` — which is the version that matters,
not whatever the current docs describe.

---

## What I learned

- **`validate` and `plan` catch a genuinely useful class of error without any
  credentials.** Wrong block names, missing required arguments, bad references
  and type mismatches all surface offline. That is the whole argument for
  running them on every pull request rather than discovering the problem during
  a deploy.

- **Unknown-at-plan-time is a real boundary for policy-as-code.** A gate that
  reads `.change.after` gets `null` for anything derived from a resource that
  does not exist yet, and a naive check will silently pass. Knowing which
  attributes are knowable at plan time is a prerequisite for writing rules that
  mean anything.

- **The provider schema is the documentation.** `terraform providers schema
  -json` answers "what is this block called and what does it require" for the
  exact pinned version, in seconds, with no guessing.

- **Deriving thresholds from the objective is the whole point of doing this in
  Terraform.** The value is not that dashboards are in Git — it is that
  `availability_slo_target` appears once and seven resources stay consistent
  with it. Clicking the same change through a UI across two SLOs, four monitors
  and a dashboard is where drift comes from.

---

## To actually apply this

```bash
export TF_VAR_datadog_api_key="..."     # from a secret store, never committed
export TF_VAR_datadog_app_key="..."
export TF_VAR_datadog_validate=true     # let the provider check credentials

terraform plan -out=tfplan
terraform apply tfplan                  # apply the reviewed plan, not a fresh one
```

Applying the saved plan file rather than re-planning is the same principle as
[module 30](../30-cicd-deploy-gate/README.md)'s "promote the artifact that
passed the gate": a re-plan can differ from the one that was reviewed.

EU accounts must set `TF_VAR_datadog_api_url=https://api.datadoghq.eu/`.
