# Lab 10.02 — Base and overlays, no duplicated YAML

**CORE · 50 min**

## Context

The rule for this lab: **if you copy a YAML file and edit it, you have failed.**
Everything that differs between environments is a patch, not a copy.

## The problem

### Part 1 — restructure

```
platform/deploy/k8s/
├── base/
│   ├── kustomization.yaml
│   ├── pulse-api.yaml
│   ├── pulse-worker.yaml
│   ├── pulse-web.yaml
│   └── ...
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

The overlays must differ in at least: replica count, resource requests and
limits, log level, and the worker's concurrency. **Not one duplicated manifest.**

```bash
kubectl kustomize platform/deploy/k8s/overlays/dev  | head -40
kubectl kustomize platform/deploy/k8s/overlays/prod | head -40
diff <(kubectl kustomize .../dev) <(kubectl kustomize .../prod)
```

That last diff should show only what you intended to differ. Anything else is a
leak.

### Part 2 — the patch types

Use each at least once and record what it is for:

| Mechanism | Use it for |
|---|---|
| `patches` with a strategic merge patch | |
| `patches` with a JSON 6902 patch | |
| `replicas` | |
| `images` | |
| `configMapGenerator` | |
| `commonLabels` / `labels` | |

1. When does a strategic merge patch fail and force you to JSON 6902?
2. What does `configMapGenerator` add to the ConfigMap name, and why is that
   behaviour genuinely useful?

Question 2's answer is one of the best features in Kustomize and most people
disable it without understanding it.

### Part 3 — wire the digest in

Module 09 produces a digest. The overlay must consume it:

```yaml
images:
  - name: ghcr.io/OWNER/pulse-api
    digest: sha256:...
```

3. Who updates that digest — a human, or CI? Design it and justify.
4. If CI writes to the repo Argo watches, what loop have you created and how do
   you stop it?

### Part 4 — where the model breaks

5. Your prod overlay grows to be larger than the base. What does that tell you?
6. You need a resource in prod that does not exist in dev at all. Kustomize way?
7. You need a conditional — "if TLS enabled, add this". What does Kustomize say,
   and what does that imply about when to reach for Helm?

## Expected outcome

Both overlays rendering correctly with zero duplicated manifests, every patch
mechanism used once, and the seven questions answered.

## Verification

```bash
# Only intended differences
diff <(kubectl kustomize platform/deploy/k8s/overlays/dev) \
     <(kubectl kustomize platform/deploy/k8s/overlays/prod)
```

## Staged hints

<details><summary>Hint 1 — question 2</summary>

It appends a hash of the content to the name, and rewrites every reference to it.
So changing a ConfigMap produces a new name, which changes the pod spec, which
**triggers a rollout**. Without it, editing a ConfigMap changes nothing until
someone restarts the pods by hand — a classic "I changed the config and nothing
happened" bug. Disabling the suffix reintroduces exactly that.
</details>

<details><summary>Hint 2 — question 4</summary>

CI commits a digest → Argo syncs → nothing else happens, so there is no loop yet.
The loop appears if CI is triggered by pushes to the same branch it writes to.
Fix with `[skip ci]`, a path filter, a separate branch for rendered manifests, or
an image updater that writes with a bot identity excluded from the trigger.
</details>
