# Lab 13.06 — Adopt what already exists

**CORE · 40 min**

> Skim if your diagnostic confirmed `archive/sre-track/27-terraform-import-drift/`.

## Context

Most real Terraform work starts with infrastructure that already exists. Adopting
it without destroying it is a distinct skill from creating it.

## The problem

### Part 1 — create something by hand, then adopt it

Create a resource outside Terraform. Then write matching configuration and
import it.

```bash
terraform import <address> <id>
terraform plan            # MUST say "No changes"
```

1. Did it say "No changes" first try? What did you have to adjust?
2. **Which did you adjust — the code or the resource?** Why does that matter?

Question 2 is the discipline: you adjust the code to match reality, never the
reverse, or you have modified production during an adoption.

### Part 2 — import blocks

Modern Terraform lets you declare imports:

```hcl
import {
  to = google_storage_bucket.artifacts
  id = "pulse-artifacts-prod"
}
```

3. What does this give you that `terraform import` does not?
4. Can you review it in a PR before anything happens? Why does that matter for a
   production adoption?

### Part 3 — generate configuration

```bash
terraform plan -generate-config-out=generated.tf
```

5. How good is the generated configuration? What did it get wrong?
6. Would you ship it as-is? What has to be cleaned up?

### Part 4 — import at scale

You have twenty resources to adopt.

7. How do you find their IDs?
8. How do you verify each import produced a clean plan **before** doing the next?
9. What goes wrong if you import all twenty then plan once?

Question 9: a single destructive proposal buried among twenty imports is very
easy to approve by accident, which is how adoptions destroy things.

### Part 5 — the reverse

10. How do you remove a resource from state **without destroying it**? When would
    you want that?

## Expected outcome

A hand-made resource adopted to a clean plan, import blocks used and reviewed,
generated config critiqued, and a safe procedure for bulk adoption.

## Staged hints

<details><summary>Hint 1 — question 10</summary>

`terraform state rm`. You want it when handing a resource to another team's state,
when splitting one large state into several, or when a resource should stop being
managed but must keep existing. The danger is the mirror of an orphan: Terraform
forgets it, and nothing is tracking it any more — so it needs to be recorded
somewhere that a human reads.
</details>
