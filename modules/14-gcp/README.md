# Module 14 — Google Cloud

**6 blocks.** Requires modules 13 and 10. **The only module that costs money.**

## Cost control — read before the first command

| | |
|---|---|
| Budget ceiling | $30/month, $50 during this module only |
| Realistic spend | **Under $10 total** if you follow the teardown steps |
| Free tier | One zonal GKE cluster's management fee is covered |
| Billing model | Everything else is billed by the hour you leave it running |

**Rules, without exception:**

1. Lab 01 configures a **billing budget with an alert before any resource is
   created**. Not after.
2. Nothing is created outside Terraform. `terraform destroy` is therefore always
   sufficient — this is why module 13 came first.
3. Every session ends with `terraform destroy` and a verification that nothing
   billable survives.
4. `./platform/scripts/verify.sh cloud-clean` **fails** if billable resources
   exist. Run it before closing your laptop.

If you are short on budget, labs 02–06 can be done with `terraform plan` against
real APIs without `apply`. You lose the runtime experience but keep the design
work. Record it in `TRACKER.md` if you take this path — the same way
`archive/sre-track/23-terraform-datadog/` records being plan-only.

## Objectives

1. Reason about a cloud provider's primitives: identity, network, quota, billing.
2. Deploy Pulse to GKE using the same Terraform modules and the same Argo CD
   configuration as locally.
3. Use workload identity so no static credential exists anywhere.
4. Map GCP concepts to AWS and Azure equivalents well enough to hold an
   architecture conversation.

## Exit criteria

- [ ] I can provision a GKE cluster and deploy Pulse to it entirely from code,
      then destroy everything and prove nothing is left.
- [ ] I can explain workload identity federation and what it replaces.
- [ ] Given a `403`, I can distinguish IAM denial from an unenabled API from a
      quota limit — three very different failures with similar-looking errors.
- [ ] I can map VPC, IAM, GKE and Cloud Storage to their AWS and Azure
      equivalents and name where the analogy breaks.

## Labs

| # | Lab | Level | Cost | Time |
|---|---|---|---|---|
| 00 | Repaso (módulos 12–13) | CORE | $0 | 15 min |
| 01 | Project, billing budget and alert, APIs enabled — **before anything else** | CORE | $0 | 40 min |
| 02 | IAM and service accounts; least privilege from the start | CORE | $0 | 45 min |
| 03 | VPC and GKE Autopilot via Terraform | CORE | ~$2 | 55 min |
| 04 | Deploy Pulse via the same Argo CD config as locally; find what does not transfer | CORE | ~$3 | 55 min |
| 05 | Workload identity — no static keys | CORE | ~$1 | 45 min |
| 06 | **Teardown drill**: destroy, then hunt for survivors (orphaned disks, IPs, load balancers) | CORE | $0 | 40 min |
| 07 | Cloud mapping table: GCP ↔ AWS ↔ Azure, with the analogies that break | CORE | $0 | 45 min |
| 08 | Cost attribution with labels; find the most expensive thing you ran | EXTEND | $0 | 35 min |

## Why lab 06 is not optional

The resources that cost money are rarely the ones you remember creating.
Persistent disks outlive their pods, load balancers outlive their Services, and
static IPs outlive everything. Learning to hunt for survivors is the skill that
keeps cloud bills from becoming a story you tell later.

## Capstone layer

Pulse runs in GKE, deployed by the same GitOps configuration as locally — and
then it is destroyed, with proof.

## Verification

```bash
terraform destroy -auto-approve
./platform/scripts/verify.sh cloud-clean   # must pass with zero billable resources
gcloud billing accounts list
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
