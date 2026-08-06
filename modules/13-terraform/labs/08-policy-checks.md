# Lab 13.08 — Assertions on the plan, before apply

**EXTEND · 40 min**

> The most transferable lab in this module. You did a version of it in
> `archive/sre-track/23-terraform-datadog/`, offline against plan JSON.

## Context

Review catches what a human notices. A machine reading the plan catches what a
human skims past at 17:45 on a Friday.

## The problem

### Part 1 — the plan as data

```bash
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
jq '.resource_changes[] | {addr: .address, actions: .change.actions}' plan.json
```

1. What do the `actions` arrays look like for create, update, replace and
   destroy?
2. How do you distinguish `["delete","create"]` from `["create","delete"]` and
   why does the order matter?

### Part 2 — assertions that would have saved you

Write checks that fail the build. At minimum:

```bash
# Nothing with state may be destroyed without an explicit override
jq -e '[.resource_changes[]
        | select(.change.actions | index("delete"))
        | select(.type | test("sql|database|disk|bucket"))] | length == 0' plan.json
```

3. No destruction of stateful resources
4. No public IP or `0.0.0.0/0` ingress introduced
5. Every resource carries the required labels
6. No unencrypted storage
7. The blast radius is bounded — fail if more than N resources change at once

Check 7 is underused and catches the accident that matters: a refactor that
proposes replacing 40 resources when you expected 2.

### Part 3 — the override path

Some of those checks will legitimately need bypassing.

8. Design the override: how does someone deliberately destroy a database?
9. It must be recorded, scoped and reviewed. Same four requirements as the CVE
   exception in module 09 and the PolicyException in module 12 — implement it.

### Part 4 — into CI

Wire it into the workflow: plan → assert → require approval → apply.

10. Where do the assertions run relative to human review? Before or after, and
    why?
11. What do you do when an assertion fails on a change that is genuinely
    correct?

Question 10: before. A human should never be asked to review a plan a machine
would have rejected — you are spending the scarce resource on something automatable.

### Part 5 — the tooling question

12. You wrote these in `jq`. When would you move to Conftest/OPA, Sentinel or
    `terraform test`? What does each add?

## Expected outcome

Five or more assertions running against plan JSON, wired into CI before human
review, with a recorded and scoped override path.

## Staged hints

<details><summary>Hint 1 — question 7</summary>

Count `resource_changes` where actions are not `["no-op"]`. Set the threshold
around what a normal change looks like for your repo and require an explicit flag
above it. It is the infrastructure equivalent of a PR that touches 200 files:
possibly fine, and definitely worth stopping to look at.
</details>

<details><summary>Hint 2 — question 12</summary>

`jq` is free and fine for a handful of rules; it becomes unreadable past about
ten. Conftest/OPA gives you a real policy language with its own tests — the point
where policies need testing is the point to switch, and module 12 lab 07 made
that argument for Kyverno. Sentinel is Terraform Cloud only. `terraform test`
validates module behaviour, which is a different question from validating a plan.
</details>
