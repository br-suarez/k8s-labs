# Lab 10.05 — Permanent drift

**CORE · 45 min**

## Context

An Application that never reaches `Synced`, where Git and the cluster look
identical to the eye. Four distinct causes, each with a different fix.

## The problem

Reproduce each, diagnose it with `argocd app diff`, and fix it correctly.

### Cause A — a mutating admission webhook

Install something that injects into pods — a simple mutating webhook adding an
annotation is enough. Watch the Application go permanently `OutOfSync`.

### Cause B — API server defaulting

Remove a field with a server-side default from your manifest —
`spec.template.spec.dnsPolicy`, or a Service's `sessionAffinity`. Apply.

1. Why does this cause drift when you did not change anything?

### Cause C — another controller owning a field

Enable the HPA from module 04 and leave `replicas` in your Deployment manifest.

2. Who wins? What happens over time?
3. Why is this the most dangerous of the four?

### Cause D — the field you must not ignore

Make a manual change to a field that matters — a resource limit. With
`selfHeal: false`, watch it report `OutOfSync` correctly.

Then add `ignoreDifferences` for that field and observe what the status says.

4. Is it `Synced` now? Is the difference gone?
5. **Turn `selfHeal` on with that `ignoreDifferences` still in place.** What
   happens to your manual change, and what does the UI say while it happens?

Question 5 is the break-fix of this module, constructed forwards.

## The fixes

For each cause, the right response is different:

| Cause | Correct fix | Wrong fix |
|---|---|---|
| A — webhook | `ignoreDifferences` scoped to the injected field | Disabling the webhook |
| B — defaulting | Add the field, or ignore it | Fighting the API server |
| C — other controller | Remove `replicas` from the manifest entirely | `ignoreDifferences` on replicas |
| D — real change | Put it in Git | `ignoreDifferences` |

6. For C, why is removing the field better than ignoring it?
7. State the rule for when `ignoreDifferences` is legitimate, in one sentence.

## Expected outcome

Four causes reproduced and diagnosed, each fixed the right way, and a written
rule for `ignoreDifferences`.

## Staged hints

<details><summary>Hint 1 — question 6</summary>

`ignoreDifferences` hides the difference but Argo still applies your manifest on
sync, so it will periodically stomp the HPA's value back to yours and the HPA
will move it again. Removing the field means Argo has no opinion, so there is
nothing to fight over. Ignoring treats the symptom; removing removes the
conflict.
</details>

<details><summary>Hint 2 — question 7</summary>

Legitimate when another system is the rightful owner of that field and you have
deliberately ceded it. Never to silence a difference you find annoying —
that turns your sync status into a value that cannot be trusted, which is worse
than no status at all.
</details>
