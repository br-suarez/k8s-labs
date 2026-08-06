# Lab 12.04 — The gate, and its opening hours

**CORE · 50 min**

## Context

Do the break-fix first. This lab builds the correct version of the policy that
failed there, and the failure teaches more when you meet it cold.

## The problem

### Part 1 — install and block something

Install Kyverno (`v1.18.2`). Write a policy that refuses unsigned images:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-signature
      match:
        any:
          - resources: { kinds: [Pod] }
      exclude:
        any:
          - resources: { namespaces: [kube-system, kyverno] }
      verifyImages:
        - imageReferences: ["*"]
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/<you>/devops-sre-mastery/.github/workflows/ci.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
```

Prove it works:

```bash
kubectl run bad --image=nginx:alpine -n pulse        # must be refused
kubectl run good --image=ghcr.io/<you>/pulse-api@sha256:... -n pulse   # must pass
```

1. Read the rejection message. Is it useful to a developer who has never seen
   this policy?
2. Improve it so it is. What does a good policy rejection message contain?

### Part 2 — the three settings that decide whether it means anything

Test each and record what changes:

| Setting | Try | Observe |
|---|---|---|
| `validationFailureAction` | `Audit` vs `Enforce` | |
| `background` | `false` vs `true` | |
| `failurePolicy` | `Ignore` vs `Fail` | |
| `imageReferences` | `["ghcr.io/you/*"]` vs `["*"]` | |

3. With `imageReferences` scoped to your registry, deploy a Docker Hub image.
   Refused or admitted? Why?
4. With `background: true`, run `kubectl get policyreport -A`. What appears?

### Part 3 — the window

Reproduce the break-fix mechanism deliberately:

```bash
# Scale the admission controller to zero — simulates an upgrade window
kubectl scale deployment kyverno-admission-controller -n kyverno --replicas=0

# With failurePolicy: Ignore
kubectl run sneaky --image=nginx:alpine -n pulse     # what happens?

kubectl scale deployment kyverno-admission-controller -n kyverno --replicas=1
kubectl get pod sneaky -n pulse                      # is it still there?
```

5. Did it get in? Is it still running once the controller is back?
6. Now repeat with `failurePolicy: Fail`. What happens to the `kubectl run`?
7. What else stops working with `Fail` while the controller is down?

### Part 4 — the deadlock

In a **scratch cluster**, set `failurePolicy: Fail` with no namespace exclusions
and restart the cluster.

8. What happens? Can Kyverno start?
9. How do you recover?
10. What is the minimum set of exclusions that avoids this?

Do not do this on the cluster carrying your work.

### Part 5 — state, not just flow

11. Write the check that inventories every running image and verifies each
    signature. Add it to `verify.sh` as the `security` group.
12. Why is this necessary even with a perfect admission policy?

## Expected outcome

A working enforcing policy, all four settings tested, the admission window
reproduced, a deadlock caused and recovered in a scratch cluster, and a state
check in the harness.

## Staged hints

<details><summary>Hint 1 — question 7</summary>

Everything that creates pods: Deployments scaling up, the scheduler replacing a
failed pod, DaemonSets on a new node, CronJobs firing. With `Fail` and a dead
webhook, your cluster cannot self-heal — which is precisely when you need it to.
</details>

<details><summary>Hint 2 — question 10</summary>

The namespaces that must come up before the webhook can serve: `kube-system` and
Kyverno's own. Some setups also need the CNI's namespace, since without network
the webhook is unreachable anyway. Keep the list short, explicit, and commented
with *why* each one is there — an unexplained exclusion becomes a permanent hole.
</details>
