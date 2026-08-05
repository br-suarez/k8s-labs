# Lab 10.04 — Ordering, and when you actually need it

**CORE · 45 min**

## Context

Kubernetes has no declarative ordering: you apply everything and controllers
converge by retrying. That is usually enough — and the cases where it is not are
specific and worth recognising.

## The problem

### Part 1 — prove convergence works

Apply Pulse's manifests in deliberately wrong order — Deployment before its
ConfigMap, Service before its pods.

1. What did the pods do while the ConfigMap was missing?
2. How long until everything converged?
3. Did anything need intervention?

The answer is usually "nothing", and that matters: **most ordering anxiety is
unfounded**, and sync waves added defensively are complexity you pay for forever.

### Part 2 — build a case that does NOT converge

Now construct one that genuinely cannot self-resolve:

- A CRD and a custom resource that uses it, applied together
- A database migration Job that must complete before the app starts
- A namespace and resources inside it

4. Which of the three fail permanently, and which converge eventually? Test each.
5. Why does the CRD case fail differently from the ConfigMap case?

### Part 3 — sync waves

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

Order the platform correctly. Then verify Argo respects it:

```bash
argocd app sync pulse --dry-run
kubectl get events -n pulse --sort-by=.lastTimestamp
```

6. What is the default wave? Can it be negative?
7. Does Argo wait for a wave to be **healthy** before starting the next, or only
   for it to be applied? This distinction matters a great deal — test it.

### Part 4 — hooks

Sync waves order resources. Hooks run things *around* the sync.

Implement the migration Job as a `PreSync` hook:

```yaml
annotations:
  argocd.argoproj.io/hook: PreSync
  argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

8. Difference between a `PreSync` hook and wave `-1`?
9. What happens to the sync if the hook Job fails?
10. What does `hook-delete-policy` control, and what goes wrong without it?

### Part 5 — the honest assessment

11. Which of your sync waves are genuinely necessary, and which did you add out
    of caution? Remove the unnecessary ones and confirm nothing breaks.

Question 11 is the point of the lab. Ordering constraints you do not need are
complexity you carry forever.

## Expected outcome

A demonstration that most ordering resolves itself, three cases that do not, waves
and a hook working, and unnecessary waves removed after testing.

## Staged hints

<details><summary>Hint 1 — question 7</summary>

Argo waits for the wave's resources to be **healthy** before the next, which is
what makes waves useful and also what makes a stuck wave block the whole sync
indefinitely. A resource with no health assessment is treated as healthy
immediately — so a wave containing only such resources provides no ordering
guarantee at all.
</details>

<details><summary>Hint 2 — question 10</summary>

Without a delete policy, hook Jobs accumulate: one per sync, forever, until they
hit namespace quota or someone notices hundreds of completed Jobs.
`HookSucceeded` deletes on success and keeps failures for debugging, which is
usually what you want.
</details>
