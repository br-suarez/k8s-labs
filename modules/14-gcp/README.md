# Module 14 — Google Cloud

**7 blocks.** Requires modules 13 and 10. **The only module that costs money.**

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
| 08 | **Unit economics**: cost per 1,000 probes, derived from your own billing export and the metrics from module 07 | CORE | $0 | 55 min |
| 09 | **Rightsizing from evidence**: what Pulse actually uses vs what it requests, and what the gap costs annually | CORE | $0 | 50 min |
| 10 | Cost attribution with labels; find the most expensive thing you ran | EXTEND | $0 | 35 min |

### On labs 08 and 09 — cost as a reliability concern

Cost is not a finance topic that happens to touch infrastructure. It is a
constraint on reliability decisions, and an SRE who cannot answer "what would
three replicas instead of two cost us per year?" cannot participate in the
conversation where that gets decided.

Both labs are `$0` because they analyse data you already generated: the billing
export from labs 01–06, and the resource metrics from module 07. The output is a
number per unit of work — cost per 1,000 probes — which is the only form in which
cost is comparable across time, across services, and against revenue.

Deliberately **not** included: reserved instances, committed use discounts,
spot-instance strategy. Those are real and they are procurement decisions, not
engineering ones, and you cannot practise them on $10 of GKE.

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
