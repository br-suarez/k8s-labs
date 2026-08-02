# Lab 08b.02 — The verifier says no

**CORE · 40 min**

## Context

The reason it is safe to load code into a running kernel is a static analyser
that must prove your program terminates and stays inside its own memory. The
fastest way to understand it is to be rejected by it.

## The problem

### Part 1 — get rejected, four ways

Write a program for each, run it, and **record the exact error**:

1. **An unbounded loop.**
   ```bash
   bpftrace -e 'BEGIN { $i = 0; while ($i >= 0) { $i++; } }'
   ```

2. **Reading memory you do not own** — dereference a pointer from a probe
   argument without `str()` or a bounded read helper.

3. **Too many instructions** — a deeply unrolled loop that exceeds the
   complexity limit.

4. **Unchecked map lookup** — use the result of a lookup that may be null.

For each: what did the verifier say, and what property was it proving?

### Part 2 — read a verifier log

```bash
bpftrace -d -e 'tracepoint:syscalls:sys_enter_openat { @[comm] = count(); }' 2>&1 | head -40
```

5. What is the verifier actually walking through?
6. What does "R1 type=ctx expected=fp" mean? (Register types are the core of
   how it reasons.)

### Part 3 — the properties it guarantees

Write in `NOTAS.md`, in your own words:

7. Which four properties does the verifier prove before a program loads?
8. Why is bounded iteration allowed in modern kernels but arbitrary loops still
   are not?
9. What is the instruction limit on your kernel, and why does one exist at all?
10. **The design question:** what would break if the verifier did not exist, and
    why is "just be careful" not an acceptable answer for kernel code?

### Part 4 — maps and why they exist

```bash
bpftrace -e '
tracepoint:syscalls:sys_enter_openat { @count[comm] = count(); }
interval:s:5 { print(@count); clear(@count); }'
```

11. Where does `@count` live? Which process reads it and how does it get there?
12. What is a per-CPU map and what problem does it solve? What does it cost?

## Expected outcome

Four rejections with their exact messages, and the twelve questions answered.

## Staged hints

<details><summary>Hint 1 — question 8</summary>

Bounded loops (`bpf_loop`, and compiler-verified bounded `for`) are allowed
because the verifier can compute a maximum iteration count and therefore prove
termination. An arbitrary loop with a runtime condition cannot be bounded
statically, so it could hang the kernel — with interrupts disabled, on a CPU that
never comes back. Termination is not a preference here; it is a requirement.
</details>

<details><summary>Hint 2 — question 12</summary>

A per-CPU map gives each CPU its own copy, so concurrent updates need no locking
and there is no cache-line contention. Cost: memory multiplied by CPU count, and
the reader has to sum across CPUs, so you cannot read a globally consistent value
at a single instant. Classic throughput-versus-consistency trade, and the right
default for counters.
</details>

## Why this lab exists

Every eBPF tool you will use — Pixie, Parca, Hubble, Falco — is built on this
model. Understanding the constraint explains why those tools are shaped the way
they are, and why an eBPF-based agent is a far smaller risk than a kernel module
doing the same job.
