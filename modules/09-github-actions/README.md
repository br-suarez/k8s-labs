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
| 00 | [Repaso](./labs/00-repaso.md) (módulos 08b–08c) | CORE | 15 min |
| 01 | [Build, test, vet](./labs/01-first-pipeline.md) — and drive it from `gh` | CORE | 40 min |
| 02 | [Caching, and where it lies](./labs/02-caching.md) | CORE | 45 min |
| 03 | [**The chain of custody**](./labs/03-digest-chain.md) — the digest travels between jobs | CORE | 40 min |
| 04 | [Scan, SBOM, and the exception path](./labs/04-scan-sbom.md) | CORE | 45 min |
| 05 | [The gate that catches a green liar](./labs/05-deploy-gate.md) | CORE | 50 min |
| 06 | [No static keys anywhere](./labs/06-oidc.md) — OIDC to GCP | EXTEND | 45 min |
| 07 | [Reusable workflows and the trust boundary](./labs/07-reusable.md) | EXTEND | 35 min |

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
