# Lab 14.02 — Least privilege from the start

**CORE · 45 min · $0**

## Context

Granting `Owner` and moving on is the default behaviour, and it is how a
compromised CI pipeline becomes a compromised cloud account. Getting it right at
the start costs an hour; retrofitting it costs a project.

## The problem

### Part 1 — the hierarchy

```bash
gcloud projects get-iam-policy PROJECT_ID --format=json | jq '.bindings'
gcloud organizations list 2>/dev/null || echo "no org — personal account"
```

1. What roles exist on your project right now, and who holds them?
2. If you have an organisation: how do roles inherit from org → folder →
   project? Can a project-level grant *reduce* an inherited one?

Question 2's answer surprises people: IAM is additive. A project-level binding
cannot take away what was granted higher up. Removing access means removing it
where it was granted, or using a deny policy.

### Part 2 — build the deployer, one permission at a time

Create a service account for the pipeline. Grant **nothing** initially.

```bash
gcloud iam service-accounts create pulse-deployer \
  --display-name="Pulse CI deployer"
```

Now try to do what CI needs, and add permissions only as things fail:

```bash
gcloud container clusters describe pulse --zone=... \
  --impersonate-service-account=pulse-deployer@PROJECT.iam.gserviceaccount.com
```

3. What was the first failure? Read the error — it names the missing permission.
4. Add the narrowest role that grants it. Repeat until CI's task succeeds.
5. What roles did you end up with? Compare against `roles/owner`.

This build-up-from-nothing approach is slower than granting Owner and it is the
only way to end up with a defensible set.

### Part 3 — predefined versus custom

6. Look at what a predefined role like `roles/container.developer` actually
   contains: `gcloud iam roles describe roles/container.developer`. How many
   permissions? How many do you need?
7. Build a custom role with only the permissions you found in part 2.
8. What is the maintenance cost of a custom role? When is a slightly-too-broad
   predefined role the better engineering choice?

Question 8 is the honest trade-off: custom roles drift out of date as APIs
change, and a stale custom role breaks deploys at the worst time.

### Part 4 — the impersonation pattern

9. Instead of keys, use impersonation locally:
   `gcloud config set auth/impersonate_service_account ...`. What does that
   change about how you test IAM changes?
10. What permission does *your* user need to impersonate? Who else has it?

## Expected outcome

A deployer service account built up from zero permissions, a documented final
role set, a custom role built and its maintenance cost assessed, and
impersonation working locally.

## Staged hints

<details><summary>Hint 1 — reading a 403 properly</summary>

GCP's permission-denied errors name the exact missing permission, like
`container.clusters.get`. Then
`gcloud iam roles list --filter="includedPermissions:container.clusters.get"`
shows which roles contain it, so you can pick the narrowest. This loop is the
whole technique.
</details>
