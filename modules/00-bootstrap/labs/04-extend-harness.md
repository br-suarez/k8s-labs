# Lab 00.04 — Extend the harness

**EXTEND · 20 min**

> Skip this if you are behind schedule. Come back to it in a reserve week — but
> do come back, because module 01 builds directly on it.

## Context

The break-fix in this module is caused by insufficient memory, and the symptom
points at Kubernetes. A check that catches it up front turns a two-hour debugging
session into a one-line failure message.

## The problem

Add a `resources` group to
[`platform/scripts/verify.sh`](../../../platform/scripts/verify.sh) that fails
when the environment cannot support the cluster profile in use.

Requirements:

1. New function `group_resources`, registered in `ALL_GROUPS`.
2. Reads the intended profile from `${PULSE_PROFILE:-lite}`.
3. Fails if available memory is below the profile's floor: `lite` 3 GiB,
   `standard` 5 GiB, `ha` 7 GiB.
4. Fails if free disk on `/` is under 20 GiB — image layers add up fast.
5. Warns (does not fail) if `nproc` reports fewer than 4 CPUs.
6. Passes `shellcheck` with no warnings.

## Expected outcome

```bash
./platform/scripts/verify.sh resources
PULSE_PROFILE=ha ./platform/scripts/verify.sh resources   # should fail on 8 GiB hosts
```

## Verification

```bash
shellcheck platform/scripts/verify.sh && echo "clean"
./platform/scripts/verify.sh resources
```

## Staged hints

<details><summary>Hint 1 — getting available memory as a number</summary>

`free -g` truncates and will report 0 for anything under 1 GiB. Prefer parsing
`/proc/meminfo`, which is in kB and exact:

```bash
awk '/^MemAvailable:/ {print int($2/1024/1024)}' /proc/meminfo
```

Use `MemAvailable`, not `MemFree`. `MemFree` excludes reclaimable page cache and
will make you think you have far less memory than you do.
</details>

<details><summary>Hint 2 — mapping a profile to a floor</summary>

An associative array is the readable option:

```bash
declare -A FLOOR=([lite]=3 [standard]=5 [ha]=7)
```

Handle an unknown profile name explicitly rather than defaulting to 0 — a silent
pass is worse than a loud failure.
</details>

<details><summary>Hint 3 — the check helper wants a command</summary>

`check` runs a command and passes on exit 0. For a comparison, wrap it:
`check "enough memory" bash -c '[ "$(...)" -ge N ]'`. Make the failure output say
what it found and what it needed — a check that just says FAIL wastes the
opportunity.
</details>

## Why this lab exists

You are building the tool that catches the failure before it costs you an
evening. Every module from here adds a group to this file, and by module 16 it is
the thing that tells you the whole platform is healthy in one command.
