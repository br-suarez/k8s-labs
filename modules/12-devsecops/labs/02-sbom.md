# Lab 12.02 — An SBOM that travels with the image

**CORE · 45 min**

## Context

An SBOM in a CI artifact answers questions for as long as your retention policy
lasts. An SBOM attested to the image answers them from the cluster, years later.

## The problem

### Part 1 — generate

```bash
syft ghcr.io/<you>/pulse-api:latest -o spdx-json > sbom.spdx.json
syft ghcr.io/<you>/pulse-api:latest -o cyclonedx-json > sbom.cdx.json
```

1. How many components? Does the number surprise you for a static Go binary?
2. Diff the two formats. What does each capture that the other does not?
3. Which would you standardise on, and why?

### Part 2 — attest it

Attach the SBOM to the image itself, signed:

```bash
cosign attest --predicate sbom.spdx.json --type spdxjson \
  ghcr.io/<you>/pulse-api@sha256:...
```

Then verify and read it back from the registry alone:

```bash
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp '.*' --certificate-oidc-issuer-regexp '.*' \
  ghcr.io/<you>/pulse-api@sha256:... | jq -r '.payload' | base64 -d | jq '.predicate.name'
```

4. Where does the attestation physically live?
5. What happens to it if you delete the tag but keep the digest?
6. Why sign the attestation and not just store it?

### Part 3 — answer a real question

Simulate the Monday morning after a CVE lands in a widely used library.

7. Which of your running images contain it? Answer using **only** the registry
   and the cluster — no CI logs.
8. Time it.
9. Now answer the same question for an image built four months ago whose CI run
   has aged out of retention. Can you?

Question 9 is the entire argument for attestation over artifacts.

### Part 4 — wire it into CI

Add generation and attestation to the module 09 pipeline, keyed to the digest
from the build job.

10. At what point in the pipeline? Before or after the vulnerability scan? Why?

## Expected outcome

SBOM attested and verifiable from the registry, a CVE question answered and
timed, and the pipeline updated.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

Even `CGO_ENABLED=0` binaries carry every Go module in the dependency tree, and
syft reads them from the binary's embedded build info. "No dependencies" meant no
*runtime shared libraries*, which is a different statement — and the SBOM is what
makes the difference visible.
</details>

<details><summary>Hint 2 — question 4</summary>

As an OCI artifact in the same repository, referenced by a tag derived from the
image digest. So it travels with the image across registry copies, and it is
addressed by digest — which means it cannot be silently swapped the way a tag
can.
</details>
