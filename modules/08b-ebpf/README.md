# Module 08b — eBPF & Continuous Profiling

**4 blocks.** Requires modules 01, 07 and 08.

## Why it sits exactly here

You have just spent six blocks instrumenting Pulse by hand: adding spans,
choosing attributes, wiring a Collector. That is the *semantic* approach — you
decide what matters and you write it down.

This module is the opposite approach. **Observe a running system without
touching it**: no code change, no restart, no redeploy. Putting the two back to
back is what makes the trade-off visible, and being able to argue it is the
point.

It also answers the question that instrumentation cannot: *what do you do when
you cannot change the code?* A vendor binary, a legacy service nobody owns, a
production incident right now. That constraint is normal, and an SRE who is
helpless without instrumentation is an SRE with a large blind spot.

## Objectives

1. Trace syscalls, file access and network activity of a running process without
   restarting it.
2. Understand eBPF's safety model well enough to explain why loading code into
   the kernel is not reckless.
3. Produce a CPU flamegraph of a live workload and find the hot path.
4. See problems that live **below** the application — where no span or
   application metric reaches.

## Exit criteria

- [ ] Given a black-box binary in a pod, I can determine what it opens, what it
      connects to, and what syscalls dominate — **without restarting it**.
- [ ] I can explain the verifier, maps, and why an eBPF program cannot loop
      forever or read arbitrary kernel memory.
- [ ] I can produce a flamegraph of `pulse-api` under load and name the hot path.
- [ ] I can argue eBPF-based observability against instrumentation, in both
      directions, and state which I would reach for first in a given incident.

## The honest comparison

The thing this module exists to teach, stated up front so the labs can test it:

| | Instrumentation (module 08) | eBPF (this module) |
|---|---|---|
| Needs code change | Yes | No |
| Needs restart | Yes | No |
| Business context | **Yes** — tenant, check ID, user intent | No |
| Coverage | Only what you instrumented | **Everything on the box** |
| Sees below the app | No | **Yes** — kernel, sockets, disk |
| Overhead | Predictable, in your control | Depends on what you attach |
| Works on third-party binaries | No | **Yes** |

They are complements, not competitors. The failure mode is a team that has one
and believes it has observability.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) (módulos 07–08) | CORE | 15 min |
| 01 | [Trace a process you cannot touch](./labs/01-bpftrace.md) | CORE | 55 min |
| 02 | [The verifier says no](./labs/02-verifier.md) — the safety model, from being rejected by it | CORE | 40 min |
| 03 | [Continuous profiling](./labs/03-profiling.md) — a flamegraph of a live pod | CORE | 55 min |
| 04 | [Below the application](./labs/04-network.md) — flows, retransmits and what traces never show | CORE | 50 min |
| 05 | [The honest comparison](./labs/05-comparison.md) — same question, both approaches, measured | EXTEND | 40 min |
| 06 | [What did attaching cost?](./labs/06-overhead.md) | EXTEND | 30 min |

## Capstone layer

No new service. Pulse gains **continuous profiling** and network-flow visibility,
both obtained without modifying a line of its code — which is itself the
demonstration.

## Verification

```bash
./platform/scripts/verify.sh profiling
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
