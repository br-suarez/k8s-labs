# Lab 14.07 — The other two clouds, honestly

**CORE · 45 min · $0**

## Context

You are learning one cloud deeply. This lab is what makes that defensible in an
interview where the other two come up — and it is a reading and writing lab, not
a hands-on one.

## The problem

### Part 1 — the mapping

Build it in `modules/14-gcp/CLOUD-MAPPING.md`, in English:

| Concept | GCP | AWS | Azure |
|---|---|---|---|
| Isolation boundary for billing/IAM | Project | Account | Subscription |
| Virtual network | VPC | VPC | VNet |
| Managed Kubernetes | GKE | EKS | AKS |
| Object storage | Cloud Storage | S3 | Blob Storage |
| Identity for workloads | Workload Identity | IRSA | Managed Identity |
| Secret storage | Secret Manager | Secrets Manager | Key Vault |
| Managed Postgres | Cloud SQL | RDS | Azure Database |
| Serverless containers | Cloud Run | App Runner / Fargate | Container Apps |
| IaC state backend | GCS | S3 + DynamoDB | Storage Account |

Fill it in and extend it with anything Pulse actually uses.

### Part 2 — where the analogy breaks

This is the valuable half. For each, write what is genuinely different:

1. **The isolation boundary.** A GCP project, an AWS account and an Azure
   subscription are not equivalent in cost, in how quickly you can create one, or
   in what crosses between them. Which is cheapest to create per environment?

2. **Identity.** GCP grants roles on resources in a hierarchy; AWS attaches
   policies to principals with permission boundaries and resource policies;
   Azure separates identity (Entra) from authorisation (RBAC). What breaks if you
   translate a GCP role to AWS literally?

3. **Networking.** VPC peering, transit gateways, private endpoints — where do
   the models diverge most?

4. **Managed Kubernetes.** What does each give you that the others do not?
   Autopilot has no exact equivalent.

### Part 3 — the question you will be asked

5. *"We're on AWS. Does your GCP experience transfer?"* Write your answer in five
   sentences. It should be specific about what transfers (Kubernetes,
   containers, Terraform, the operational model) and honest about what does not
   (IAM specifics, networking primitives, managed service behaviour).

6. *"Why did you learn GCP and not AWS?"* Answer without being defensive. The
   real answer is that one cloud deeply teaches the model, and the model is what
   transfers.

## Expected outcome

`CLOUD-MAPPING.md` complete, four "where it breaks" sections written from
understanding rather than copied, and two interview answers prepared.

## Why this lab exists

Most job postings name a cloud you have not used. The candidates who do well are
not the ones who claim all three — they are the ones who can say precisely what
transfers and what they would need a week to learn.
