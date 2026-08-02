# Module 03 — Docker & Image Supply Chain

**4 blocks** (2 if you pass the diagnostic). Requires module 01.

Not "how to write a Dockerfile". You have done that. This is about what an image
*is* — layers, digests, provenance — because modules 09 and 12 sign and verify
these artifacts, and you cannot secure what you cannot describe.

## Objectives

1. Build minimal, reproducible images and explain every layer in them.
2. Debug a container that builds cleanly and fails at runtime.
3. Understand image identity: tags versus digests, and why tags are not
   identity.
4. Compose a multi-service stack with correct dependency and health semantics.

## Exit criteria

- [ ] I can write a multi-stage Dockerfile producing a distroless image under
      25 MB, from scratch, without a template.
- [ ] Given a container in `CrashLoopBackOff` with no logs, I have a repeatable
      diagnostic sequence and can name what each step rules out.
- [ ] I can explain why `image: app:latest` is unsafe in a Deployment and what
      digest pinning costs operationally.
- [ ] I can explain layer caching well enough to predict which source change
      invalidates which layer.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) (módulos 01–02) | CORE | 15 min |
| 01 | [Multi-stage to distroless](./labs/01-multistage.md) — under 25 MB, non-root, working outbound TLS | CORE | 45 min |
| 02 | [Layer archaeology](./labs/02-layer-archaeology.md) — the mechanism, not the rule | CORE | 40 min |
| 03 | [Three containers that build clean and fail at runtime](./labs/03-broken-containers.md) | CORE | 50 min |
| 04 | [Compose the stack](./labs/04-compose.md) with health-gated startup | CORE | 45 min |
| 05 | [Tags are not identity](./labs/05-tags-vs-digests.md) | CORE | 30 min |
| 06 | [Build reproducibility](./labs/06-reproducibility.md) | EXTEND | 40 min |

## Capstone layer

The whole platform runs in Compose with health-gated startup:

```bash
docker compose up -d
./platform/scripts/verify.sh nginx
```

Images are distroless, non-root, and referenced by digest.

## Key distinction for this module

`depends_on` without `condition: service_healthy` only waits for the container to
*start*, not to be *ready*. This is the same mistake as a Kubernetes Deployment
with no readiness probe, and you will meet it again in module 04 — recognising
it as the same bug in a different syntax is the point.

## Verification

```bash
docker compose up -d --wait
./platform/scripts/verify.sh nginx
docker images pulse-api --format '{{.Size}}'   # under 25MB
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
