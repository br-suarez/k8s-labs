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
| 00 | [Repaso](./labs/00-repaso.md) (módulos 07–09) | CORE | 15 min |
| 01 | [Bootstrap, and what it did to your cluster](./labs/01-bootstrap.md) | CORE | 40 min |
| 02 | [Base and overlays, no duplicated YAML](./labs/02-kustomize.md) | CORE | 50 min |
| 03 | [App of apps](./labs/03-app-of-apps.md) — and its blast radius | CORE | 50 min |
| 04 | [Ordering, and when you actually need it](./labs/04-sync-waves.md) | CORE | 45 min |
| 05 | [**Permanent drift**](./labs/05-drift.md) — four causes, four different fixes | CORE | 45 min |
| 06 | [The 3am procedure](./labs/06-emergency.md) | CORE | 40 min |
| 07 | [Who writes the new digest?](./labs/07-image-updates.md) | EXTEND | 40 min |
| 08 | [AppProjects and multi-tenancy](./labs/08-rbac.md) | EXTEND | 35 min |

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
