# Lab 14.05 — No keys, anywhere

**CORE · 45 min · ~$1**

## Context

Two separate problems that people conflate: how CI authenticates to GCP, and how
a pod authenticates to GCP. Both have keyless answers and they are different
mechanisms.

## The problem

### Part 1 — pods to GCP

Pulse needs to write probe artifacts to a bucket. The lazy path is a service
account key in a Secret.

Do it the right way — GKE Workload Identity:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  pulse-storage@PROJECT.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:PROJECT.svc.id.goog[pulse/pulse-worker]"

kubectl annotate serviceaccount pulse-worker -n pulse \
  iam.gke.io/gcp-service-account=pulse-storage@PROJECT.iam.gserviceaccount.com
```

1. What did that binding actually say? Read it in words.
2. How does the pod obtain a token? What is it talking to?
3. What happens if a pod in a *different* namespace uses the same Kubernetes
   service account name?

Question 3 checks whether you understand the binding is scoped to
namespace **and** name.

### Part 2 — CI to GCP

Different mechanism: workload identity **federation** with GitHub's OIDC issuer,
from module 09 lab 06.

4. Configure it, scoped to your repository and to `refs/heads/main` only.
5. Try to authenticate from a branch. It must fail.
6. What does the attribute condition look like? What happens without one?

Question 6 has a severe answer: a provider that trusts the issuer without an
attribute condition accepts a token from **any** GitHub repository in existence.

### Part 3 — prove there are no keys

```bash
gcloud iam service-accounts keys list \
  --iam-account=pulse-deployer@PROJECT.iam.gserviceaccount.com
```

7. Any user-managed keys? There should be none.
8. Search your repo and CI secrets for anything that looks like a key.
9. Add an organisation policy or a check that prevents key creation.

### Part 4 — the trade-offs

10. What did you gain? Name the threat you closed, specifically.
11. What is harder now? (Local development, and debugging an auth failure.)
12. Your GKE cluster is gone but the IAM bindings remain. Is that a problem?

Question 12 is worth thinking about: bindings referencing a deleted cluster's
identity pool are inert but they are also cruft, and they accumulate.

## Expected outcome

Pods authenticating without keys, CI federated and correctly scoped, a branch
refused, zero user-managed keys, and the threat closed stated specifically.

## Cleanup

```bash
terraform destroy -auto-approve
./scripts/verify-cloud-clean.sh PROJECT_ID
```
