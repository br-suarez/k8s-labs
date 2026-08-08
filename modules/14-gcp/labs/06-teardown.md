# Lab 14.06 — Hunt the survivors

**CORE · 40 min · $0**

## Context

This lab is the break-fix, done deliberately. Do the break-fix cold first if you
have not — finding orphaned resources from a bill is more instructive than being
shown them.

## The problem

### Part 1 — create the conditions

Deploy Pulse to GKE with a PVC and a LoadBalancer Service. Let it run for a few
minutes so the cloud controllers do their work.

```bash
gcloud compute disks list
gcloud compute forwarding-rules list
gcloud compute addresses list
```

1. What exists now that did not before you deployed?
2. Who created each one? Not you, and not Terraform.
3. Is any of it in `terraform state list`?

### Part 2 — destroy naively and count the damage

```bash
terraform destroy -auto-approve
```

Then look again:

```bash
gcloud compute disks list
gcloud compute forwarding-rules list
gcloud compute addresses list
gcloud asset search-all-resources --scope="projects/$PROJECT" \
  --format="table(assetType,displayName)"
```

4. What survived? Compute the monthly cost of leaving it.
5. Why did Terraform not remove it? State the mechanism in one sentence.

### Part 3 — the ordered teardown

Delete the Kubernetes objects **before** the cluster:

```bash
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --wait=true
kubectl delete pvc --all --all-namespaces --wait=true
sleep 60
terraform destroy -auto-approve
```

6. Did that leave a clean project? Verify.
7. Why the `sleep`? What is happening during it, and what would a proper wait
   look like?
8. What is fragile about this approach?

### Part 4 — do not rely on part 3

Write `scripts/verify-cloud-clean.sh`:

- Uses `gcloud asset search-all-resources`, not per-service enumeration
- Excludes the things that legitimately persist — service accounts, the project,
  the budget
- Exits non-zero with a list when anything billable remains

9. Test it against a dirty project and a clean one.
10. Why is asset search better than enumerating `compute disks`,
    `forwarding-rules`, and so on?

### Part 5 — make it automatic

11. Add it to `verify.sh` as the `cloud-clean` group.
12. Wire it into the Terraform destroy path so a destroy that leaves survivors
    fails loudly.
13. What would you do in a real organisation where you cannot run this manually
    after every change?

## Expected outcome

Orphans created and counted with their monthly cost, an ordered teardown that
leaves nothing, and an automated survivor check that does not trust the ordered
teardown.

## Staged hints

<details><summary>Hint 1 — question 8</summary>

It depends on `kubectl` being configured, on the delete completing before the
timeout, and on a fixed sleep being long enough. Any of the three failing leaves
orphans silently. That is why part 4 exists: the check must not depend on the
cleanup having worked.
</details>

<details><summary>Hint 2 — question 13</summary>

Scheduled scanning at the organisation level with a report of unattached disks,
unused addresses and orphaned forwarding rules, plus mandatory labelling so
ownership is attributable. The manual check is the lab version of a control that
in production has to be continuous — same conclusion as scanning in module 12.
</details>
