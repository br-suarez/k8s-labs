# Lab 10.07 — Who writes the new digest?

**EXTEND · 40 min**

> Skip if behind schedule. Decide it before module 11, because the canary needs
> a defined path from "new image exists" to "cluster runs it".

## Context

Module 09 produces a digest. Module 10 deploys what is in Git. Something has to
connect them, and the two options have genuinely different properties.

## The problem

### Part 1 — CI writes back

CI commits the new digest to the overlay after a successful build.

Implement it. Then answer:

1. What identity does CI use to commit? What access does it need to the repo?
2. How do you stop that commit from triggering CI again?
3. What happens if two builds finish close together? (You solved this shape in
   module 09 — does the same fix apply?)
4. Is the commit reviewable? Should it be?

### Part 2 — Argo CD Image Updater

Install it and let it detect new images and write them back.

5. How does it authenticate to the registry? To Git?
6. What update strategies exist, and which is right for digest-pinned images?
7. It can write back to Git or annotate the Application directly. What is lost
   with the second?

Question 7 matters: writing to the Application object means the cluster's state
is no longer fully described by Git, which quietly breaks the property GitOps
exists for.

### Part 3 — compare

| | CI writes back | Image Updater |
|---|---|---|
| Who has repo write access | | |
| Reviewable | | |
| Works for third-party images | | |
| Extra component to run | | |
| Behaviour when the registry is unreachable | | |
| Audit trail | | |

### Part 4 — decide

8. Which for Pulse? Defend it.
9. Which would you pick for a platform team publishing base images consumed by
   thirty applications? Why is the answer different?

## Expected outcome

Both approaches working, the comparison table filled from observation, and a
defended choice.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

`[skip ci]` in the message, a path filter on the workflow trigger, or committing
with an identity the trigger excludes. The path filter is the most robust — it
does not depend on message conventions anyone can forget.
</details>

<details><summary>Hint 2 — question 9</summary>

Thirty applications means thirty pipelines each needing write access to their
manifests repo, which is thirty credentials and thirty chances to get the
write-back wrong. A single Image Updater centralises that. The trade is a
component to run and a less obvious audit trail — worth it at thirty, not at one.
</details>
