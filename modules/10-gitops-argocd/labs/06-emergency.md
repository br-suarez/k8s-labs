# Lab 10.06 — The 3am procedure

**CORE · 40 min**

## Context

GitOps says the cluster follows Git. During an incident that is sometimes too
slow. This lab produces the written procedure for going around it — the document
you need to have **before** you need it.

## The problem

### Part 1 — feel the problem

With `selfHeal: true`, break Pulse in a way a manual patch would fix:

```bash
# Set a memory limit that guarantees OOMKill
kubectl patch deployment pulse-api -n pulse --type=json -p \
  '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"24Mi"}]'
git add -A && git commit -m "break it" && git push
argocd app sync pulse
```

Now fix it by hand and time how long your fix survives.

1. Exactly how long? Which Argo setting determines that number?
2. What did the Argo UI say during the cycle?

### Part 2 — the three mitigation options

Try each and record scope and cost:

```bash
argocd app set pulse --self-heal=false                      # a
argocd app set pulse --sync-policy none                     # b
kubectl scale deployment argocd-application-controller -n argocd --replicas=0   # c
```

3. What does each stop? What does each keep working?
4. Which would you use at 3am, and why not the other two?
5. What is the specific danger of (c)?

### Part 3 — write the procedure

Create `platform/RUNBOOK-emergency-change.md`, in English. It must cover:

1. How to disable self-heal for **one** Application, with the exact command
2. The explicit instruction never to scale down the controller
3. How to announce the manual change, and to whom
4. The requirement that a PR exists **before** the incident is closed
5. How to re-enable and verify
6. The postmortem question: why was Git too slow?

Keep it under one screen. A runbook nobody can read at 3am is decoration.

### Part 4 — make the procedure enforceable

6. How would you detect that an Application has had self-heal disabled and left
   that way? Write the check.
7. Add it to `platform/scripts/verify.sh` as part of the `gitops` group.

That check is what stops "temporarily disabled" from becoming permanent — the
same failure mode as the CVE exception in module 09.

### Part 5 — the real finding

8. Time how long a legitimate change takes through the normal path: commit →
   CI → merge → Argo sync → pods running.
9. If that number is over 15 minutes, what would you change? People bypass slow
   processes, and no amount of policy fixes that.

## Expected outcome

A measured self-heal reversion, three mitigations compared, a one-page runbook,
an automated check for lingering disabled self-heal, and the normal-path latency
measured.

## Verification

```bash
./platform/scripts/verify.sh gitops
```

## Staged hints

<details><summary>Hint 1 — question 6</summary>

```bash
kubectl get applications -n argocd -o json \
  | jq -r '.items[] | select(.spec.syncPolicy.automated.selfHeal != true)
           | .metadata.name'
```

Anything listed is an Application not being self-healed. During an incident that
is correct; a week later it is drift waiting to happen.
</details>
