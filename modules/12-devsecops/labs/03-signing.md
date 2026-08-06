# Lab 12.03 — Keyless signing

**CORE · 50 min**

## Context

Signing with a long-lived key means you now have a long-lived key to protect,
rotate and eventually lose. Keyless removes the key and replaces it with an
identity — which is both better and different in ways worth understanding.

## The problem

### Part 1 — key-based first, to see what you are replacing

```bash
cosign generate-key-pair
cosign sign --key cosign.key ghcr.io/<you>/pulse-api@sha256:...
cosign verify --key cosign.pub ghcr.io/<you>/pulse-api@sha256:...
```

1. Where does the signature live?
2. Where must `cosign.key` live for CI to use it? Who can read it there?
3. If it leaks, what can an attacker do? How would you find out?
4. What is your rotation plan? Be honest about whether you would actually do it.

### Part 2 — keyless

```bash
COSIGN_EXPERIMENTAL=1 cosign sign ghcr.io/<you>/pulse-api@sha256:...
```

Locally this opens a browser. In CI it uses the workflow's OIDC token — which is
the point.

Add it to the module 09 pipeline:

```yaml
permissions:
  id-token: write
  packages: write
steps:
  - uses: sigstore/cosign-installer@v3
  - run: cosign sign --yes "${IMAGE}@${DIGEST}"
```

### Part 3 — verify the identity, not just the signature

This is the step that makes keyless worth it:

```bash
cosign verify \
  --certificate-identity-regexp "^https://github.com/<you>/devops-sre-mastery/.github/workflows/ci.yml@refs/heads/main$" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/<you>/pulse-api@sha256:... | jq
```

5. What exactly are you asserting with that identity regex?
6. Sign from a **branch** and verify with the same command. Does it pass? It must
   not.
7. What would `--certificate-identity-regexp '.*'` accept? Why is it almost
   always wrong?

Question 7 matters: that flag appears in most tutorials and it accepts a
signature from **anyone**, which makes verification theatre.

### Part 4 — the transparency log

```bash
cosign verify ... | jq '.[0].optional.Bundle.Payload.logIndex'
rekor-cli get --log-index <index>
```

8. What is recorded in Rekor? Is it your image?
9. What does the log let you detect that a signature alone cannot?
10. What is the privacy implication of every signature being public?

### Part 5 — what it does not prove

11. Your build pipeline is compromised and produces a backdoored image, then
    signs it. Does verification pass?
12. What would be needed to catch that?

## Expected outcome

Keyless signing in CI, verification pinned to a specific workflow and branch, a
branch signature correctly refused, and questions 11–12 answered honestly.

## Staged hints

<details><summary>Hint 1 — question 11</summary>

Yes, it passes. The signature attests *who built it*, not *that it is correct*.
A compromised builder produces validly signed malware. Closing that needs
provenance attestation — binding artifact to source and build parameters — plus
reproducible builds so an independent party can rebuild and compare. That is the
gap SLSA levels describe, and module 03 lab 06 is where you met the other half.
</details>

<details><summary>Hint 2 — question 9</summary>

An append-only public log means a signature cannot be created retroactively and
hidden. You can ask "were there signatures for my identity that I did not make?"
— detecting a stolen identity after the fact. With a private key and no log,
an attacker who signs with your key leaves no trace anywhere.
</details>
