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
| 00 | [Repaso](./labs/00-repaso.md) (módulos 09–11) | CORE | 15 min |
| 01 | [Triage, not a wall of red](./labs/01-triage.md) — Trivy v0.72.0 and reachability | CORE | 45 min |
| 02 | [An SBOM that travels with the image](./labs/02-sbom.md) | CORE | 45 min |
| 03 | [Keyless signing](./labs/03-signing.md) — Cosign v3.1.2, and what a signature does not prove | CORE | 50 min |
| 04 | [**The gate, and its opening hours**](./labs/04-admission.md) — Kyverno v1.18.2 | CORE | 50 min |
| 05 | [Harden the pods, then fix what breaks](./labs/05-hardening.md) | CORE | 50 min |
| 06 | [base64 is not encryption](./labs/06-secrets.md) | CORE | 40 min |
| 07 | [Policies are code, so test them](./labs/07-policy-tests.md) | EXTEND | 40 min |
| 08 | [Break glass](./labs/08-break-glass.md) | EXTEND | 35 min |

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
