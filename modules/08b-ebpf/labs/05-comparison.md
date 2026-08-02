# Lab 08b.05 — The honest comparison

**EXTEND · 40 min**

> Skip if behind schedule, but the deliverable is a strong interview artifact —
> few engineers can argue this well, and it comes up whenever someone proposes
> buying an eBPF-based observability product.

## Context

You now have both approaches working on the same system. Answer the same
questions with each and record what it actually took.

## The problem

For each question below, answer it **twice** — once with instrumentation
(modules 07/08), once with eBPF — and record: could you answer it at all, how
long it took, and what you had to change.

| # | Question | Instrumentation | eBPF |
|---|---|---|---|
| 1 | What is the p99 latency of `/api/checks`? | | |
| 2 | Which tenant's requests are slowest? | | |
| 3 | Which function burns the most CPU? | | |
| 4 | What files does the worker open? | | |
| 5 | How long do connections wait before `accept()`? | | |
| 6 | Which requests failed and why, in business terms? | | |
| 7 | What is Postgres doing during a slow request? | | |
| 8 | Same question, but for a third-party binary you cannot rebuild | | |

## What to record per cell

- **Could you?** yes / no / partially
- **Time to answer**
- **What it required** — code change, restart, new deploy, privileges, nothing

## The write-up

`modules/08b-ebpf/COMPARISON.md`, in English, structured as advice to a team
choosing where to spend effort:

1. The filled table.
2. Which questions only instrumentation answers, and why. (Row 2 and row 6 are
   the interesting ones.)
3. Which questions only eBPF answers, and why. (Rows 5 and 8.)
4. Which both answer — and which you would use in practice, given cost.
5. A recommendation for a team with limited effort: what to do first.
6. **The failure mode**: what breaks in a team that has only one of the two and
   believes it has observability.

## The conclusion to reach on your own

Do not read this until the table is filled.

<details><summary>After you have filled it in</summary>

eBPF gives **breadth without cooperation**: everything on the machine, including
things you did not write, with no code change. It cannot give you semantics —
it sees a 4 KB write to a socket, not that it was tenant 4471's checkout.

Instrumentation gives **depth with meaning**, at the cost of touching every
service and covering only what you thought to instrument.

The practical sequence: alerts and SLOs from instrumented metrics because they
carry the business meaning; traces to localise; eBPF when the answer is not in
either, which usually means the problem is below your code.

A team with only eBPF cannot define a meaningful SLO. A team with only
instrumentation is blind below `accept()` and helpless with any binary it did not
build. Both blindnesses are expensive; they are just expensive at different
times.
</details>
