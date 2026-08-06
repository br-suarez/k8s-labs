# Lab 13.07 — Workspaces or directories

**EXTEND · 45 min**

> Genuinely contested, which is why it is worth having a defended position rather
> than a preference.

## Context

Two ways to manage multiple environments. Most teams pick one by accident and
then argue about it.

## The problem

### Part 1 — workspaces

```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace select prod
```

Use `terraform.workspace` to vary configuration.

1. Where does each workspace's state live?
2. What is shared between workspaces, and what is not?
3. What happens if you run `apply` while on the wrong workspace? How would you
   notice?

Question 3 is the strongest argument against workspaces, and it is worth
experiencing rather than reading.

### Part 2 — directory per environment

```
environments/
├── dev/
│   ├── main.tf          # calls the shared module
│   └── backend.tf
└── prod/
    ├── main.tf
    └── backend.tf
```

4. What is duplicated? Is that duplication bad?
5. Can dev and prod use different module versions? Should they be able to?

Question 5 is the strongest argument *for* directories: dev can adopt a new
module version before prod, which is exactly what you want for a risky change.

### Part 3 — compare on real criteria

| | Workspaces | Directories |
|---|---|---|
| Risk of applying to the wrong environment | | |
| Environments can diverge in versions | | |
| Duplicated code | | |
| Fits a CI pipeline per environment | | |
| Different backends or credentials per env | | |
| Discoverability for a newcomer | | |

### Part 4 — decide

6. Which for Pulse? Defend it.
7. Which would you mandate for a team of fifteen managing production? Is the
   answer different, and why?
8. What is the case where workspaces are clearly right?

Question 8 has a good answer: many identical short-lived environments — one per
pull request, one per customer — where the whole point is that they do **not**
diverge.

## Expected outcome

Both implemented, the comparison table filled from experience, and a defended
choice with the case for the alternative stated.

## Staged hints

<details><summary>Hint 1 — question 3</summary>

Nothing stops you. The prompt does not show it by default, and the plan looks
plausible because it is the same code. The usual mitigations are a shell prompt
showing the workspace and a `precondition` that fails when the workspace does not
match an expected variable — both are seatbelts for a design that lets the
mistake happen at all.
</details>
