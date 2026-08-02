# Module 09 — CI with GitHub Actions

**4 blocks.** Requires module 03.

## Objectives

1. Build a pipeline that produces a signed, scanned, digest-addressed artifact.
2. Make CI fast without making it lie — caching that does not mask failures.
3. Handle secrets and permissions with least privilege, using OIDC rather than
   long-lived credentials.
4. Write a deployment gate that blocks a release that is technically healthy but
   actually broken.

## Exit criteria

- [ ] I can write a workflow from scratch that builds, tests, scans, generates an
      SBOM and publishes by digest.
- [ ] I can explain why `pull_request_target` is dangerous and when it is
      nonetheless the right choice.
- [ ] I can configure OIDC to a cloud provider and explain what it replaces and
      why that is better.
- [ ] Given a pipeline that passes while shipping a broken release, I can identify
      what the gate failed to check.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 07–08) | CORE | 15 min |
| 01 | Build, test, vet on push; matrix across two Go versions | CORE | 40 min |
| 02 | Layer and module caching; measure before and after; find the case where the cache serves stale results | CORE | 45 min |
| 03 | Publish by digest to GHCR, never by mutable tag | CORE | 40 min |
| 04 | Trivy scan + SBOM generation as artifacts; fail on HIGH, with a documented exception path | CORE | 45 min |
| 05 | **The deploy gate**: reject a release that reports `READY=true, RESTARTS=0` while failing 19% of requests | CORE | 50 min |
| 06 | OIDC to GCP — no static keys anywhere in the repo | EXTEND | 45 min |
| 07 | Reusable workflows and the security boundary they cross | EXTEND | 35 min |

## Capstone layer

Every push to `main` builds Pulse, tests it, scans it, produces an SBOM, and
publishes digest-addressed images. The harness from module 01 runs as the gate.

## Note on the deploy gate

Lab 05 recreates the failure from `archive/sre-track/30-cicd-deploy-gate/`. Doing
it again is deliberate: this time the gate runs in real CI against a real
registry, and the interesting failure is different — a gate that false-negatives
a healthy release is as expensive as one that misses a broken one.

## Verification

Green badge on `main`, plus:

```bash
cosign verify --key cosign.pub ghcr.io/<you>/pulse-api@sha256:...
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
