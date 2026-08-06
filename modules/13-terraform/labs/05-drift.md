# Lab 13.05 — Drift in two directions

**CORE · 45 min**

> If your diagnostic confirmed `archive/sre-track/27-terraform-import-drift/`,
> skim this and spend the time on labs 07 and 08 instead.

## Context

Drift is not one thing. Whether the configuration or reality is wrong determines
which command you reach for, and getting it backwards either stomps a legitimate
change or blesses an unauthorised one.

## The problem

### Part 1 — reality changed

Modify a managed resource outside Terraform.

```bash
terraform plan                 # what does it propose?
terraform plan -refresh-only   # what does this propose?
```

1. What does each want to do to the **same field**?
2. Which is correct? It depends on something the tool cannot know — what?

### Part 2 — configuration changed

Now change the configuration instead, leaving reality alone.

3. What does each command propose now?
4. Why is `-refresh-only` uninteresting in this direction?

### Part 3 — both changed

The genuinely hard case: someone modified reality **and** someone changed the
configuration, differently.

5. What does `plan` show? Does it distinguish the two changes?
6. How do you work out what the manual change was, if it is about to be
   overwritten?
7. What would have preserved that information? (Audit logs on the cloud provider,
   and a rule that manual changes are announced — same conclusion as module 10.)

### Part 4 — continuous detection

Drift you find in six months is not detection.

```bash
terraform plan -detailed-exitcode
# 0 = no changes, 1 = error, 2 = changes present
```

8. Write a scheduled job that runs this and alerts on exit code 2.
9. Where should that alert go, and how do you stop it becoming noise?
10. What is the difference between drift you should auto-correct and drift a
    human must look at?

Question 10 is the interesting one and mirrors Argo CD's self-heal from module
10: automatic correction is right when the configuration is authoritative, and
wrong when the manual change was an emergency fix nobody has committed yet.

## Expected outcome

Both drift directions demonstrated on the same field, the both-changed case
worked through, and a scheduled detection job with an alerting policy.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

Terraform cannot know whether the manual change was a mistake or a legitimate
emergency fix. `plan` assumes the code is authoritative; `-refresh-only` assumes
reality is. The decision is human and needs context the tool does not have —
which is why an unannounced manual change is expensive regardless of who was
right.
</details>
