# Lab 00.02 — Memory and the WSL ceiling

**CORE · 30 min**

## Context

This track peaks at roughly 6 GiB of cluster workload in module 07. WSL2 gives
you half your host RAM by default. If those numbers do not work out, you will
find out in week 10, mid-module, with a Prometheus pod in `OOMKilled`.

Find out now instead.

## The problem

1. Measure what you actually have:

```bash
free -h
nproc
df -h /
```

2. Work out your host's total RAM (WSL's default is 50% of it) and decide your
   ceiling. **75% of host RAM is the maximum** — leaving Windows under 4 GiB
   makes the whole machine swap, and you will blame Kubernetes for it.

3. Write `C:\Users\<you>\.wslconfig` with your chosen values. Use the template
   in [`SETUP.md`](../../../SETUP.md#0-the-memory-problem--read-this-first).

4. Apply it — from **PowerShell**, not from inside WSL:

```powershell
wsl --shutdown
```

5. Re-enter WSL and confirm the change took effect.

## Expected outcome

`free -h` shows your new total. Record the before and after in `NOTAS.md`,
including which cluster profile you are committing to for the rest of the track.

## Verification

```bash
# Should print your configured total, not the old default
free -g | awk '/^Mem:/ {print "total GiB:", $2}'
```

## Staged hints

<details><summary>Hint 1 — nothing changed after editing .wslconfig</summary>

`.wslconfig` is read when the WSL VM boots. Editing it while WSL is running
changes nothing. Did `wsl --shutdown` actually run, and did every WSL terminal
close? A single open session keeps the VM alive.
</details>

<details><summary>Hint 2 — I cannot find .wslconfig</summary>

It does not exist by default. You create it. It lives in your Windows user
profile (`C:\Users\<you>\`), **not** in the Linux filesystem — `~/.wslconfig`
inside WSL does nothing at all.
</details>

<details><summary>Hint 3 — my host only has 8 GB</summary>

Then set `memory=6GB`, commit to the `lite` profile for the whole track, and
note it in `TRACKER.md`. Module 07 documents reduced-retention values for
exactly this case. The track works; it just has less headroom.
</details>

## Why this lab exists

It is the single most common cause of "Kubernetes is broken" in a local lab
environment, and the symptom never mentions memory.
