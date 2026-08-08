# Lab 14.03 — VPC and GKE, from the module you already wrote

**CORE · 55 min · ~$2**

> Cost warning: this lab creates billable resources. Read part 5 before you
> start, and do not close your laptop without running it.

## Context

The Terraform modules from module 13 should need a new provider and little else.
Where they need more, that is design feedback.

## The problem

### Part 1 — network first

Write Terraform for a VPC with a subnet and secondary ranges for pods and
services.

1. Why do GKE pods and services need secondary IP ranges?
2. How many pod IPs does your range allow? How many nodes does that support?
3. What happens when you run out? Can you change it later?

Question 3 is the one that bites years later: pod CIDR is effectively immutable
on an existing cluster.

### Part 2 — the cluster

Use **Autopilot**, not Standard.

```hcl
resource "google_container_cluster" "pulse" {
  name             = "pulse"
  location         = var.region
  enable_autopilot = true
  network          = google_compute_network.pulse.id
  subnetwork       = google_compute_subnetwork.pulse.id
  # deletion_protection defaults to true — decide deliberately
}
```

4. Autopilot vs Standard: what do you give up, and what does it cost per hour?
5. `deletion_protection` — leave it on or off for a lab? What about production?
6. How long did `apply` take? Compare against `kind create cluster`.

### Part 3 — how much are you spending, right now

Before doing anything else:

```bash
gcloud billing accounts list
# and in the console, the cost breakdown for this project
```

7. What is the hourly rate you have just committed to? Multiply by 24 and by
   30 — is that inside your budget?

Do this arithmetic **now**, not at the end of the month.

### Part 4 — reuse or rewrite?

8. How much of your module 13 code survived? What had to change?
9. Was the module abstraction useful, or did you effectively rewrite it for GCP?
10. What would a genuinely provider-portable module look like? Is it worth it?

Question 9 is the honest test of the module you wrote in 13, and the answer is
often "it did not survive contact with a second provider".

### Part 5 — destroy, now

```bash
terraform destroy -auto-approve
./scripts/verify-cloud-clean.sh PROJECT_ID
```

11. Anything left? There should not be yet — you have not deployed workloads.
    That comes in lab 04, and so does the interesting part of the teardown.

## Expected outcome

VPC and Autopilot cluster from Terraform, hourly cost computed and checked
against budget, an honest assessment of module portability, and a clean destroy.

## Cost control

| | |
|---|---|
| Estimated | ~$2 if destroyed within the session |
| Free tier | One zonal cluster's management fee is covered |
| **Rule** | Never end a session without `destroy` + `verify-cloud-clean.sh` |
