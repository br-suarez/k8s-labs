# Lab 12.01 — Triage, not a wall of red

**CORE · 45 min**

## Context

A scanner will give you hundreds of findings. The skill is not running it — it is
deciding which three matter, and being able to defend having ignored the rest.

## The problem

### Part 1 — scan three things

```bash
trivy image ghcr.io/<you>/pulse-api:latest
trivy image golang:1.23
trivy image ubuntu:24.04
```

1. How many findings each? Explain the spread in one sentence.
2. Your distroless final image versus the `golang` build stage — why the
   difference, and what does that say about multi-stage builds as a *security*
   measure and not just a size one?

### Part 2 — classify what you found

For each finding in your own image, put it in a bucket:

| Bucket | Meaning | What you do |
|---|---|---|
| Your code | A dependency you chose | Upgrade it |
| Base image | Comes from upstream | Rebuild on a newer base, or accept |
| Transitive | A dependency of a dependency | Upgrade the parent, or wait |
| Not reachable | Present, never called | Document and move on |

3. How many are actually in the first bucket?
4. How would you *prove* something is in the last bucket rather than assuming it?

### Part 3 — reachability

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
cd platform/services/pulse-api && govulncheck ./...
```

5. How many findings does `govulncheck` report versus Trivy?
6. Why the difference? Which is more useful for deciding what to fix today?
7. What does Trivy see that `govulncheck` cannot?

Question 7 keeps you honest: `govulncheck` only knows Go. Anything in the base
image — a vulnerable libc, an OS package — is invisible to it.

### Part 4 — the number that matters

8. Pick the single most important finding across all your images and justify it
   in three sentences: what it is, why it is reachable in your context, and what
   an attacker gains.

If you cannot write those three sentences for any finding, that is a real and
reportable result — and a much more honest output than a list of 200 CVEs.

## Expected outcome

Three scans compared, findings bucketed, `govulncheck` run and contrasted, and
one finding justified in three sentences.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

The build stage contains a compiler, a package manager, source, and the whole
toolchain — hundreds of packages, each with a CVE history. The distroless final
image contains your binary and a CA bundle. Multi-stage is a security control
precisely because none of the build tooling ships, and that is a stronger
argument for it than image size.
</details>

<details><summary>Hint 2 — question 4</summary>

Proving unreachability means showing the vulnerable function is never called on
any path from your entry points. `govulncheck` does that with call-graph
analysis for Go. Without that kind of tooling you are asserting, not proving —
and the honest way to record it is "assumed unreachable, not verified".
</details>
