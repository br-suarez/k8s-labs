# Module 01 — Linux & Scripting

**4 blocks** (2 if you pass the diagnostic). Requires module 00.

Scripting is not a module you finish. The harness you build here is extended by
every module that follows, so you practise it sixteen more times rather than once.

## Objectives

1. Write bash that fails loudly and correctly — the difference between a script
   that reports a problem and one that silently continues past it.
2. Diagnose a process from the outside: what it is blocked on, what it is opening,
   what it is asking the kernel for.
3. Build the verification harness the rest of the track depends on.

## Exit criteria

- [ ] I can write a script with correct error handling, argument parsing and
      cleanup **from a blank file, without a template**.
- [ ] Given a process consuming CPU with no logs, I can determine whether it is
      CPU-bound, I/O-bound or blocked on a lock, and name the command that told me.
- [ ] `make lint` passes with zero shellcheck warnings across the repo.
- [ ] I can explain why `set -e` is not sufficient error handling, and name two
      cases where it silently does nothing.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) | CORE | 15 min |
| 01 | [The script that lies](./labs/01-failing-loudly.md) | CORE | 45 min |
| 02 | [Reading a process from outside](./labs/02-process-forensics.md) | CORE | 60 min |
| 03 | [Build the platform harness](./labs/03-platform-harness.md) | CORE | 60 min |
| 04 | [Signals and graceful shutdown](./labs/04-signals.md) | EXTEND | 40 min |

## Capstone layer

Pulse gets its build tooling and the `build`, `scripts` and `resources` check
groups. By the end of this module:

```bash
make build && make lint && make verify
```

...produces two working binaries and a green harness.

## Verification

```bash
./platform/scripts/verify.sh build scripts resources
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
