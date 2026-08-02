# Module 10 — GitOps with Argo CD

**5 blocks.** Requires modules 09 and 04.

## Objectives

1. Make the cluster's state a consequence of the repository, not of your terminal.
2. Structure manifests with Kustomize so environments differ by overlay, not by
   copy.
3. Understand sync waves, hooks and self-heal well enough to predict Argo's
   behaviour before you click.
4. Diagnose drift and know when self-heal is wrong.

## Exit criteria

- [ ] I can bootstrap Argo CD and deploy Pulse via app-of-apps from a clean
      cluster, with no `kubectl apply` anywhere.
- [ ] I can explain sync waves and predict the ordering of a multi-resource sync.
- [ ] Given an application stuck `OutOfSync` that looks identical in Git and
      cluster, I can find the mutating admission controller or default causing it.
- [ ] I can defend Argo CD against Flux and against plain CI-driven `kubectl
      apply`, naming a case for each.

## Exit criterion worth stating precisely

Self-heal is not always right. If a human patched a Deployment at 3am to stop an
outage, self-heal reverts the fix. Knowing when to disable it — and having a
documented path for emergency changes that does not fight the controller — is
what separates operating GitOps from installing it.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 08–09) | CORE | 15 min |
| 01 | Bootstrap Argo CD; understand what it did to the cluster | CORE | 40 min |
| 02 | Kustomize base and overlays for dev/prod; no duplicated YAML | CORE | 50 min |
| 03 | App-of-apps for the whole Pulse platform | CORE | 50 min |
| 04 | Sync waves and hooks: force a correct ordering that fails without them | CORE | 45 min |
| 05 | **Permanent drift**: an app that never reaches Synced because something mutates it | CORE | 45 min |
| 06 | Self-heal vs the 3am patch — write the emergency procedure | CORE | 40 min |
| 07 | Image updater or CI-writes-back: pick one and justify it | EXTEND | 40 min |
| 08 | Argo CD RBAC and multi-tenancy | EXTEND | 35 min |

## Capstone layer

The cluster is governed by Git. `kubectl apply` becomes a debugging tool, not a
deployment mechanism. Deleting a Pulse resource by hand results in Argo putting
it back.

## Verification

```bash
argocd app get pulse
kubectl delete deployment pulse-api -n pulse   # watch it come back
./platform/scripts/verify.sh k8s gitops
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
