# Lab 08b.06 — What did attaching cost?

**EXTEND · 30 min**

> Skip if behind schedule. Do it before you ever propose eBPF tooling for a
> production cluster — "it's basically free" is a claim you should be able to
> back with a number.

## Context

eBPF overhead is low, not zero, and it scales with the **frequency of the hook**
rather than the complexity of the program. A probe on a rare event is free; the
same probe on every context switch is not.

## The problem

### Part 1 — a baseline

```bash
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- http://pulse-api:8080/api/checks >/dev/null 2>&1; done'
```

Record for five minutes, with nothing attached: request rate, p99 latency,
CPU usage.

### Part 2 — attach, from cheap to expensive

Measure the same three numbers after each:

| Probe | Hook frequency | Δ rate | Δ p99 | Δ CPU |
|---|---|---|---|---|
| `tracepoint:syscalls:sys_enter_openat` | low | | | |
| `tracepoint:syscalls:sys_enter_write` | medium | | | |
| `profile:hz:99` (whole system) | fixed | | | |
| `kprobe:tcp_sendmsg` | per packet | | | |
| `tracepoint:sched:sched_switch` | **very high** | | | |
| `strace -c -p PID` (for comparison) | every syscall | | | |

The last row is the point of the table.

### Part 3 — reduce it

Take the most expensive probe and make it cheaper three ways:

1. **Filter in the kernel** — add a `/pid == X/` predicate rather than emitting
   everything and filtering later.
2. **Aggregate rather than emit** — `count()` and `hist()` into a map instead of
   `printf` per event.
3. **Sample** — only act on a fraction of events.

Measure after each. Which gave the biggest win?

### Part 4 — the rules

Write in `NOTAS.md`:

4. What determines eBPF overhead — the program, or the hook?
5. Why is `printf` per event so much worse than a map aggregation?
6. Which of these would you leave running permanently in production, and which
   only during an investigation?
7. What would you tell a colleague who says eBPF observability is free?

## Expected outcome

A filled measurement table, three optimisations measured, and a defensible
answer to question 7 backed by your own numbers.

## Staged hints

<details><summary>Hint 1 — question 5</summary>

`printf` sends each event to user space through a ring buffer, and something has
to read, format and write it. A map aggregation keeps everything in kernel
memory and is read once per interval. The difference is orders of magnitude on a
high-frequency hook, and it is the single most important habit when writing
these.
</details>

<details><summary>Hint 2 — question 6</summary>

Continuous profiling at 99 Hz is designed to be left on and typically costs well
under 1% CPU. A `kprobe` on `sched_switch` is an investigation tool, not a
resident agent. The rule: leave on what is sampled at a fixed low rate; attach
per-event probes only while you are watching.
</details>
