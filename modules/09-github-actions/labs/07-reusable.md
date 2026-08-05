# Lab 09.07 — Reusable workflows and the trust boundary

**EXTEND · 35 min**

> Skip if behind schedule.

## Context

Reusable workflows remove duplication and quietly move a trust boundary. Both
halves matter.

## The problem

### Part 1 — extract

Your `ci.yml` builds two services with near-identical steps. Extract a reusable
workflow taking the service name and returning the digest.

```yaml
# .github/workflows/build-service.yml
on:
  workflow_call:
    inputs:
      service: { required: true, type: string }
    outputs:
      digest: { value: ${{ jobs.build.outputs.digest }} }
```

1. What can a reusable workflow **not** do that a composite action can, and vice
   versa?
2. How do secrets reach it? What does `secrets: inherit` actually pass?

### Part 2 — the boundary

3. If you call a reusable workflow from another organisation's repository, whose
   permissions does it run with?
4. What can it read? Your secrets? Your token?
5. How do you pin it so it cannot change under you?
6. What is the difference in risk between calling a reusable workflow and calling
   a third-party action?

### Part 3 — the policy

Write in `NOTAS.md` the rule you would give a team:

- When is a reusable workflow from outside the org acceptable?
- What must be true before passing `secrets: inherit`?
- How do you audit which external workflows are in use across all repos?

## Expected outcome

Both services built through one reusable workflow, and a written trust policy.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

Secrets are not inherited by default: you pass them explicitly, or use
`secrets: inherit` which passes **all** of them. `inherit` is convenient and it
is the wrong default across a trust boundary — the called workflow gets every
secret the caller has, including ones it has no business seeing.
</details>

<details><summary>Hint 2 — question 6</summary>

An action runs *inside* your job: same runner, same token, same filesystem, and
it can read anything in the workspace. A reusable workflow runs as its own job
with its own permissions and only the secrets you pass. So a reusable workflow is
the **safer** boundary — which is a genuinely useful thing to know when choosing
between them.
</details>
