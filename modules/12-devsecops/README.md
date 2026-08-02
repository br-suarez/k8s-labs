# Module 12 — DevSecOps & Supply Chain

**5 blocks.** Requires modules 09 and 10. **Zero coverage in the reference
material** — no Trivy, no Cosign, no SBOM, no admission policy anywhere.

## Objectives

1. Know what is in your images and be able to answer "are we affected?" in
   minutes, not days.
2. Sign artifacts and verify signatures at admission, so an unsigned image
   cannot run.
3. Enforce policy in the cluster rather than trusting the pipeline.
4. Reduce the runtime attack surface: non-root, read-only root filesystem,
   dropped capabilities, seccomp.

## Exit criteria

- [ ] Given a CVE announcement, I can determine whether Pulse is affected and
      which running workloads contain the package, using the SBOMs I generated.
- [ ] I can sign an image with Cosign and configure Kyverno to reject unsigned
      images — and I can demonstrate the rejection.
- [ ] I can explain keyless signing and what the transparency log gives you that
      a key does not.
- [ ] I can explain why pipeline-only scanning is insufficient and what admission
      control adds.

## The framing that matters

Scanning in CI tells you about the image you built. It says nothing about the
image that is *running* — which may have been deployed before the CVE was
published, or pushed by someone bypassing CI entirely. Policy at admission is
what closes that gap. Being able to articulate this distinction is the difference
between "we run Trivy" and having a supply chain position.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 10–11) | CORE | 15 min |
| 01 | Trivy (v0.72.0) against Pulse images; triage findings, separate real from noise | CORE | 45 min |
| 02 | SBOM generation and attestation; answer a CVE question using it | CORE | 45 min |
| 03 | Cosign (v3.1.2) signing in CI — keyless with OIDC | CORE | 50 min |
| 04 | **Kyverno (v1.18.2) admission policy**: reject unsigned images; prove it blocks | CORE | 50 min |
| 05 | Pod hardening: non-root, read-only rootfs, dropped capabilities, seccomp — and fix what breaks | CORE | 50 min |
| 06 | Secrets: why base64 is not encryption, and what to use instead | CORE | 40 min |
| 07 | Policy as code with tests — policies are code and need their own tests | EXTEND | 40 min |
| 08 | Break-glass: how a human overrides policy during an incident, auditably | EXTEND | 35 min |

## Capstone layer

Pulse images are signed, scanned and attested. The cluster **rejects anything
unsigned**. Every workload runs non-root with a read-only root filesystem.

## Verification

```bash
cosign verify ghcr.io/<you>/pulse-api@sha256:... --certificate-identity-regexp '.*'
kubectl run rogue --image=nginx:latest    # must be rejected by policy
./platform/scripts/verify.sh security
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
