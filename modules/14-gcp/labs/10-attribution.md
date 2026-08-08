# Lab 14.10 — Who spent it?

**EXTEND · 35 min · $0**

> Skip if behind schedule.

## Context

A bill you cannot attribute is a bill nobody owns, and unowned costs never go
down.

## The problem

### Part 1 — label everything

Add labels to every Terraform resource: `service`, `environment`, `owner`,
`cost-center`.

1. Which resource types in GCP do **not** support labels? What do you do about
   those?
2. Do Kubernetes labels propagate to the cloud resources GKE creates? Test it
   with a PVC.

Question 2 has an important answer for the break-fix: the disks GKE creates carry
GKE's own naming, and attributing them back to a workload is not automatic.

### Part 2 — enforce it

3. Write the Terraform plan assertion from module 13 lab 08 that fails when a
   resource lacks the required labels.
4. Write the Kyverno policy from module 12 that requires the same labels on
   Kubernetes objects.

Two layers, because resources arrive by two paths.

### Part 3 — query by label

```sql
SELECT labels.value AS service, SUM(cost) AS cost
FROM `PROJECT.billing.gcp_billing_export_v1_XXXX`,
     UNNEST(labels) AS labels
WHERE labels.key = 'service'
GROUP BY 1 ORDER BY cost DESC
```

5. What percentage of your spend is attributable? What is unlabelled?
6. Where does the unlabelled portion come from?

The unattributable remainder is usually shared infrastructure and things created
outside your IaC — which is the same category as the orphans in the break-fix.

### Part 4 — the most expensive thing

7. What was the single most expensive thing you ran during this module?
8. Was it worth it? Would you run it again?
9. What would you have done differently knowing the number in advance?

## Expected outcome

Labels enforced at both layers, an attribution query, the unattributable share
identified, and an honest answer about your most expensive resource.

## Staged hints

<details><summary>Hint 1 — question 6</summary>

Typically: the cluster management fee, network egress, logging and monitoring
ingestion, and anything created by controllers rather than by your IaC. Some of
it is genuinely shared and needs an allocation rule rather than a label — and
deciding that rule is a policy decision, not a technical one.
</details>
