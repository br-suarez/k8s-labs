# Lab 13.03 — The platform as code

**CORE · 50 min**

## Context

The capstone layer, and the precondition for module 14 staying inside budget:
everything created by `apply`, everything removed by `destroy`, nothing by hand.

## The problem

### Part 1 — the cluster itself

Provision the kind cluster with Terraform using the `tehcyx/kind` provider or
equivalent.

1. What does Terraform manage here that the `kind` CLI does not?
2. What happens to the state if someone runs `kind delete cluster` by hand?
3. Is Terraform the right tool for a local dev cluster? Argue both sides.

Question 3 has a real answer either way, and the point is to have one.

### Part 2 — everything around Pulse

Bring the platform's supporting resources under Terraform: namespaces, the Argo
CD installation, the Gateway API CRDs, Prometheus, the Kyverno policies.

4. Which of those belong in Terraform and which belong in Git-under-Argo-CD?
   Where is the line?

That line is one of the genuinely contested questions in the field. Write your
answer and the reasoning — it is an architecture-review question.

### Part 3 — the boundary you will defend

A defensible split:

| Layer | Tool | Why |
|---|---|---|
| Cloud infrastructure, cluster itself | Terraform | Exists before Kubernetes does |
| Cluster add-ons (Argo CD, CRDs) | Terraform | Bootstrap; Argo cannot deploy itself |
| Applications and their config | Argo CD | Reconciled continuously, not on apply |

5. What breaks if you put applications in Terraform?
6. What breaks if you put the cluster in Argo CD?

### Part 4 — full cycle

```bash
terraform destroy -auto-approve
terraform apply -auto-approve
./platform/scripts/verify.sh
```

7. Time it. How long from nothing to a verified platform?
8. What needed a human? Each of those is a gap.
9. Run `destroy` then check for survivors: any kind clusters, containers,
   volumes or networks left?

## Expected outcome

The full local platform provisioned and destroyed by Terraform, a documented
Terraform/Argo boundary, and a clean destroy verified.

## Verification

```bash
terraform destroy -auto-approve
kind get clusters                    # empty
docker volume ls -q | wc -l          # no leftovers
terraform apply -auto-approve
./platform/scripts/verify.sh
```

## Staged hints

<details><summary>Hint 1 — question 5</summary>

Terraform applies on demand; Argo reconciles continuously. An application in
Terraform drifts silently until the next apply, and you lose self-heal. You also
couple app deploys to infrastructure runs, so a routine deploy needs the state
lock — which serialises everything behind infrastructure changes.
</details>

<details><summary>Hint 2 — question 6</summary>

Argo CD runs *inside* the cluster, so it cannot create the cluster it runs in.
There is a bootstrap ordering that only an external tool can satisfy. This is the
clean argument for the boundary and it holds regardless of preference.
</details>
