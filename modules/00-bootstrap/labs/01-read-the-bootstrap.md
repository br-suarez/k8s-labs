# Lab 00.01 — Read before you run

**CORE · 30 min**

## Context

You have a bootstrap script that will install eight tools and modify your
`.bashrc`. Most people run it and move on. That is how you end up with an
environment you cannot debug.

## The problem

Read [`scripts/bootstrap.sh`](../../../scripts/bootstrap.sh) end to end, then
answer these **without running it**:

1. What does `fetch_binary` do that a plain `curl -o /usr/local/bin/kind` does
   not? Why does that matter if the download fails halfway?
2. `install_kind` compares `"v$(kind version -q)"` against `$KIND_VERSION`. Why
   the `v` prefix concatenation? What would break without it?
3. The script calls `sudo` in some places but not others. List which operations
   need it and why.
4. `install_docker` prints a warning instead of running `newgrp docker` itself.
   Why can it not just fix it for you?
5. If you run the script twice, which functions do real work the second time?

## Expected outcome

Answers written in `NOTAS.md`. Then run it and see whether you were right:

```bash
./scripts/bootstrap.sh --dry-run
```

Compare the dry-run output against your prediction for question 5. Then run it
for real.

## Verification

```bash
./scripts/verify-setup.sh
```

Tooling checks should pass. `build` will skip if Go is not installed — that is
expected, module 01 installs it.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

Think about what `/usr/local/bin/kind` contains if `curl` is interrupted at 60%.
Now think about what happens on the *next* run of the script.
</details>

<details><summary>Hint 2 — question 4</summary>

Group membership is read when a process starts. `newgrp` starts a *new shell*.
What happens to that shell when the script that spawned it exits?
</details>

## Why this lab exists

The first thing you will be asked to do on any new team is run their setup
script. The engineers who can debug it when it fails on their machine are a
different category from the ones who file a ticket.
