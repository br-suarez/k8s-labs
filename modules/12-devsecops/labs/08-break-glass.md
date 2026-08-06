# Lab 12.08 — Break glass

**EXTEND · 35 min**

> Skip if behind schedule. Same shape as the emergency procedure in module 10 —
> and the reason it recurs is that every control you add needs a documented way
> around it, or people will find an undocumented one.

## Context

It is 3am. A policy is blocking the fix. You need to deploy something the policy
refuses, right now.

If there is no sanctioned path, the improvised one will be scaling down the
admission controller — which removes every control at once, for everyone,
and nobody will remember to put it back.

## The problem

### Part 1 — feel the need

Create the situation: a policy that blocks a deploy you genuinely need during an
incident. An emergency debug image, unsigned, from a public registry.

1. What are your options right now? List everything that would work.
2. Which of those leave a trace? Which are cluster-wide?
3. Which would you actually reach for at 3am, tired?

Question 3 matters more than 1: the procedure has to be the *easy* option, or it
will not be used.

### Part 2 — design the mechanism

Requirements, all four:

- **Scoped** — one namespace, one workload, not the whole cluster
- **Recorded** — the exception is an object someone can list
- **Expiring** — it stops working on its own
- **Visible** — something alerts while it is active

Kyverno's `PolicyException` is a reasonable base. Implement it:

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: incident-2026-08-emergency-debug
  namespace: pulse
spec:
  exceptions:
    - policyName: require-signed-images
      ruleNames: [check-signature]
  match:
    any:
      - resources:
          namespaces: [pulse]
          names: [debug-*]
```

4. What is missing from that manifest relative to the four requirements?
5. Kyverno exceptions have no native TTL. How do you build expiry?

### Part 3 — make expiry real

Implement it. Options: a CronJob that deletes exceptions older than N hours, a
required annotation with an expiry date plus a check that fails when passed, or
both.

6. Which did you choose? What happens if the mechanism itself fails?

### Part 4 — make it visible

7. Write the check for `verify.sh` that fails when any `PolicyException` exists.
8. Should its presence be an alert, or only a check? Argue it.

The defensible position: an alert during business hours, a check always. An
exception is legitimate for hours and suspicious after a day.

### Part 5 — write the runbook

`platform/RUNBOOK-break-glass.md`, one screen, in English:

1. The exact command, ready to copy
2. What NOT to do — never scale down the controller
3. Who to tell
4. The expiry, and who removes it
5. The postmortem question: **why did the policy block a legitimate fix?**

That last one is where the value is. A policy that blocks legitimate work
repeatedly is a badly written policy, not a discipline problem — the same
conclusion as module 10's emergency procedure.

## Expected outcome

A scoped, recorded, expiring, visible exception mechanism, a check in the
harness, and a one-page runbook.

## Staged hints

<details><summary>Hint 1 — question 6</summary>

If a CronJob is the expiry mechanism and the CronJob fails, the exception becomes
permanent and silent — the failure mode you were trying to avoid. Belt and
braces: the CronJob deletes them, *and* the harness check fails while any
exception exists, so a stuck one surfaces on the next verification run.
</details>
