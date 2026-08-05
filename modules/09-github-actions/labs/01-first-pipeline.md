# Lab 09.01 — Build, test, vet

**CORE · 40 min**

## Context

The foundation everything else in this module hangs off. Write it yourself —
copying a workflow you do not understand is how you end up with the break-fix.

## The problem

### Part 1 — the minimum that is actually correct

Write `.github/workflows/ci.yml`:

1. Triggers on push to `main` and on pull request.
2. Builds, tests and vets both services.
3. A matrix across two Go versions — the one in `go.mod` and the newest stable.
4. `permissions: contents: read` at workflow level. Nothing more.
5. `concurrency` configured, with `cancel-in-progress` different for PRs and for
   `main`. Write down why in a comment.
6. Third-party actions pinned **by commit SHA**, not by tag.

Requirement 6 is the same lesson as module 03: `actions/checkout@v4` is a mutable
tag, and a compromised action inherits your token.

### Part 2 — watch it from the terminal

You installed `gh` for this. Push and follow the run without opening a browser:

```bash
git push
gh run watch
gh run list --limit 5
gh run view --log-failed
```

`gh run view --log-failed` is the one that saves time: it prints only the failing
steps' logs instead of making you scroll a green wall.

### Part 3 — break it four ways

Make each failure happen, and record what the log looks like and how fast you
found it:

| Break | What you should see |
|---|---|
| A failing test | |
| A `go vet` warning | |
| A syntax error in the YAML | |
| A step that hangs | |

That last one matters: a hung step burns runner minutes until the job timeout.
What is the default? Set `timeout-minutes` explicitly and justify the value.

### Part 4 — the matrix question

4. If the matrix has two Go versions and one fails, what happens to the other?
5. What is `fail-fast` and when do you want it off?
6. Your matrix doubles your runner minutes. Is it worth it here? Argue both ways.

## Expected outcome

A green pipeline, four failures reproduced with their log shape, and the matrix
questions answered.

## Verification

```bash
gh run list --workflow=ci.yml --limit 1
gh run view --json conclusion -q .conclusion   # success
```

## Staged hints

<details><summary>Hint 1 — pinning by SHA</summary>

`uses: actions/checkout@8f4b7f8...` with a comment saying which version that is.
Ugly, and it is what supply-chain guidance recommends — a tag can be repointed at
malicious code by anyone who can push tags to that action's repo. Dependabot can
keep the pins updated, which is the whole answer: pin **and** renovate.
</details>

<details><summary>Hint 2 — question 5</summary>

`fail-fast: true` (default) cancels the whole matrix when one leg fails: fast
feedback, saves minutes. Off when you want the complete picture — "does this fail
on every Go version or only the newest?" is information you lose with fail-fast
on, and it is exactly the information you want when debugging a version-specific
break.
</details>
