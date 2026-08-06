# Lab 12.07 — Policies are code, so test them

**EXTEND · 40 min**

> Skip if behind schedule. Do it before you rely on a policy in production —
> an untested policy is the same category of thing as an untested backup.

## Context

Your policies now decide what may run. That makes them code with production
consequences, and code with production consequences needs tests.

## The problem

### Part 1 — test what should pass and what should not

```bash
kyverno test .
```

Write a test suite covering, for each policy:

- A resource that **must** be admitted
- A resource that **must** be refused
- An edge case — an excluded namespace, a partial match, a missing field

1. Which of your policies had no test for the refusal path?
2. Did any policy pass a resource you expected it to block?

Question 2 is the point. Most policies are only ever tested against things that
should pass.

### Part 2 — the mutation trap

If any policy mutates as well as validates, order matters.

3. Does your mutation run before or after validation?
4. Can a mutation make a resource pass a validation it should have failed?
5. How do you test the combination rather than each in isolation?

### Part 3 — into CI

Add `kyverno test` to the module 09 pipeline, so a policy change cannot merge
without passing.

6. What do you do about a policy change that passes tests but would break
   existing workloads? How do you find out **before** merging?

The answer is dry-running the new policy against the live cluster's resources —
Kyverno's CLI can apply a policy to exported manifests and report what would be
refused.

```bash
kubectl get pods -A -o yaml > /tmp/live-pods.yaml
kyverno apply new-policy.yaml --resource /tmp/live-pods.yaml
```

7. How many currently running workloads would your stricter policy have refused?

### Part 4 — the rollout question

8. You have a new policy that 30% of workloads fail. What is the rollout plan?
9. What does `Audit` mode give you here, and how do you know when it is safe to
   move to `Enforce`?

## Expected outcome

A test suite covering pass, fail and edge cases per policy, tests in CI, and a
dry-run against live resources with a count of what would break.

## Staged hints

<details><summary>Hint 1 — question 9</summary>

`Audit` records violations in PolicyReports without blocking. You move to
`Enforce` when the report has been empty for long enough to cover your full
deployment cycle — including the monthly CronJob and the rarely scaled service.
Switching after a quiet afternoon is how you discover a workload nobody deployed
this week.
</details>
