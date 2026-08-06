# Lab 12.05 — Harden the pods, then fix what breaks

**CORE · 50 min**

## Context

Every hardening setting here breaks something. Fixing what breaks is the lab —
turning the setting off is the failure mode.

## The problem

### Part 1 — measure the starting point

```bash
kubectl get pods -n pulse -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\t"}{.spec.containers[0].securityContext}{"\n"}{end}'
```

1. What is actually set right now? What is inherited by default?
2. What capabilities does a container get by default? List them.

Question 2 surprises people: the default set is not empty and includes things
like `CHOWN`, `SETUID`, `NET_RAW`.

### Part 2 — apply, one at a time

Add each and record what broke and how you fixed it **without disabling it**:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

| Setting | What broke | How you fixed it |
|---|---|---|
| `runAsNonRoot` | | |
| `readOnlyRootFilesystem` | | |
| `capabilities: drop ALL` | | |
| `seccompProfile` | | |

3. Which one broke something? What was it writing, and where?
4. What does `RuntimeDefault` seccomp actually block? How would you find out
   which syscall was denied?

Question 4 connects to module 08b: a seccomp denial shows up as a killed process
with little explanation, and tracing the syscall is exactly what eBPF is for.

### Part 3 — enforce it

Write a Kyverno policy requiring all of the above, then check the whole cluster:

```bash
kubectl get policyreport -A -o wide
```

5. Which existing workloads fail? Including the ones you did not write —
   Kyverno's own, the metrics server, Argo CD.
6. What do you do about third-party workloads you cannot modify?

### Part 4 — Pod Security Admission

Kubernetes has built-in enforcement independent of Kyverno:

```bash
kubectl label namespace pulse \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
```

7. Does Pulse still deploy? What fails?
8. What do `privileged`, `baseline` and `restricted` mean? Where is the line
   between them?
9. **PSA vs Kyverno** — what does each do that the other cannot? Do you need
   both?

### Part 5 — measure the benefit

10. With `readOnlyRootFilesystem: true` and `drop: ALL`, what can an attacker who
    achieves code execution in `pulse-api` no longer do? Be specific — name three
    things.

## Expected outcome

All settings applied and everything that broke fixed rather than disabled, the
cluster-wide report reviewed, PSA compared against Kyverno, and three concrete
attacker capabilities removed.

## Staged hints

<details><summary>Hint 1 — question 6</summary>

Namespace-scoped exceptions with a documented owner and an expiry, exactly like
the CVE exception path in module 09 lab 04. The pattern repeats because the
problem repeats: a permanent unexplained exception is indistinguishable from
having no policy.
</details>

<details><summary>Hint 2 — question 9</summary>

PSA is built in, needs no components, and applies three fixed profiles at
namespace level — cheap and coarse. Kyverno is arbitrary policy: mutation,
image verification, cross-resource rules, custom messages. Common answer: PSA as
the baseline everywhere, Kyverno for what PSA cannot express. They are
complementary, and PSA costs nothing so there is little reason to skip it.
</details>
