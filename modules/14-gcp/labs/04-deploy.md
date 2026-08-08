# Lab 14.04 — Same GitOps, different cluster

**CORE · 55 min · ~$3**

## Context

If the Argo CD configuration from module 10 deploys Pulse to GKE unchanged, the
abstraction held. Everything that needs changing is a place where it leaked.

## The problem

### Part 1 — bootstrap

Install Argo CD on GKE and apply the same root Application from module 10.

1. What worked unchanged?
2. What broke? Make a list before fixing anything.

Expect at least: StorageClass names, the Gateway/LoadBalancer setup, image pull
authentication, and resource requests that Autopilot rejects or rewrites.

### Part 2 — the leaks, one by one

For each thing that broke:

3. Was it a genuine cloud difference, or an assumption you baked in?
4. Fix it in a way that keeps **both** environments working — an overlay, not a
   fork.

Question 4 is the discipline. A GCP-specific copy of your manifests means you
now maintain two truths.

### Part 3 — Autopilot's opinions

Autopilot rewrites and rejects things Standard accepts.

```bash
kubectl get pods -n pulse -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}'
```

5. Did your resource requests survive? What did Autopilot change?
6. Which of your module 12 security settings did Autopilot enforce for you?
7. Which did it refuse to allow?

Question 6 is a pleasant surprise: Autopilot enforces several hardening
requirements by default, which is a real argument for it.

### Part 4 — reach it

Expose Pulse through a Gateway or LoadBalancer Service.

8. What cloud resources did that create? List them — `gcloud compute
   forwarding-rules list`, `addresses list`.
9. **Are those in your Terraform state?** Check.

Question 9 is the break-fix, discovered forwards. Write down what you find; you
will need it in lab 06.

### Part 5 — verify it actually works

```bash
./platform/scripts/verify.sh
```

10. Which check groups pass against GKE? Which need adjusting, and why?

### Part 6 — destroy

```bash
terraform destroy -auto-approve
./scripts/verify-cloud-clean.sh PROJECT_ID
```

11. **Now** what is left? Compare against lab 03's clean result.

If lab 06 is not immediately next in your session, do the cleanup from its part 2
before stopping. Do not leave this running.

## Expected outcome

Pulse running on GKE from the same GitOps config, every leak fixed via overlay,
the cloud resources Kubernetes created identified and confirmed absent from
Terraform state, and a destroy whose leftovers you have documented.

## Cost control

| | |
|---|---|
| Estimated | ~$3 for a working session |
| **Never** | End a session without destroy + survivor check |
