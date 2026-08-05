# Lab 09.06 — No static keys anywhere

**EXTEND · 45 min**

> Skip if behind schedule. Needed before module 14 deploys to GCP from CI — come
> back to it then at the latest.

## Context

The default way teams authenticate CI to a cloud is a service account key in a
secret. It works, and it is a long-lived credential sitting in a system that runs
third-party code.

## The problem

### Part 1 — the thing you are replacing

Before configuring OIDC, write down what a static key costs:

1. Where does it live, and who can read it?
2. What is its lifetime? Who rotates it, and when did that last happen?
3. If it leaks, how would you know? How long would it be valid?
4. Which of your workflows can currently use it?

Question 4 is the uncomfortable one: usually **all of them**, including workflows
added later by anyone with write access.

### Part 2 — configure workload identity federation

Set up GCP to trust GitHub's OIDC issuer, scoped as tightly as you can:

- Restrict to your repository
- Restrict to a specific ref (`refs/heads/main`), not any branch
- Bind to a service account with only the permissions the deploy needs

Then in the workflow:

```yaml
permissions:
  id-token: write     # required to request the OIDC token
  contents: read

steps:
  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: projects/.../providers/github
      service_account: deployer@....iam.gserviceaccount.com
```

### Part 3 — prove the scoping works

5. Create a branch, try to use the same workflow from it. Does it authenticate?
   It should not.
6. Decode the OIDC token's claims. Which ones does GCP check?
7. What happens if you omit `id-token: write`?

### Part 4 — the trade-offs

8. What did you gain? Be specific about the threat you closed.
9. What did you make harder? (Local reproduction, and debugging when it fails.)
10. What breaks if you rename the repository? (You just renamed one — this is not
    hypothetical.)

## Expected outcome

Working keyless authentication, scoping proven by a branch that is correctly
refused, and the ten questions answered.

## Staged hints

<details><summary>Hint 1 — question 6</summary>

`sub` (usually `repo:owner/name:ref:refs/heads/main`), `aud`, `iss`,
`repository`, `workflow`, `job_workflow_ref`. The attribute condition in GCP is
what actually enforces the scoping — an unconstrained provider that trusts the
issuer alone will accept a token from **any** GitHub repository in the world.
That misconfiguration is common and total.
</details>

<details><summary>Hint 2 — question 10</summary>

If the attribute condition pins `repository`, renaming breaks authentication
until you update it. That is a real operational cost of tight scoping, and worth
knowing before it happens on a Friday.
</details>
