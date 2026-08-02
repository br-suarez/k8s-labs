# Lab 08b.03 — A flamegraph of a live pod

**CORE · 55 min**

## Context

Continuous profiling answers "where does the CPU actually go?" in production,
continuously, at a cost low enough to leave on. No profiler build, no restart, no
special binary.

## The problem

### Part 1 — profile by hand first

Before deploying anything, sample the stacks yourself:

```bash
bpftrace -e '
profile:hz:99 /pid == PID/ { @[ustack] = count(); }
interval:s:30 { exit(); }'
```

1. Why 99 Hz and not 100? (There is a real reason and it is not arbitrary.)
2. Are the stacks readable, or full of hex addresses? If the latter — why, and
   what does the binary need for them to resolve?

That second question is the one that bites: a stripped Go binary built with
`-ldflags="-s -w"` — **which is exactly what you did in module 03** — loses the
symbols the profiler needs. Go back and look at the trade-off you recorded then.

### Part 2 — deploy continuous profiling

Deploy Parca or Pyroscope. Point it at Pulse.

Record its footprint against your cluster budget, and its scrape overhead.

### Part 3 — generate a hot path and find it

```bash
kubectl set env deployment/pulse-api -n pulse INJECT_CPU_BURN=true
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- http://pulse-api:8080/api/results >/dev/null 2>&1; done'
```

Find the hot path from the flamegraph alone — no reading the source first.

3. Which function dominates? What proportion of samples?
4. How deep is the stack to reach it?
5. Now read the code. Were you right?

### Part 4 — read it correctly

The questions that separate looking at flamegraphs from reading them:

6. What does the **horizontal axis** represent? (Not time. Not order.)
7. What does the **vertical axis** represent?
8. A wide frame near the top versus a wide frame near the bottom — what does each
   mean?
9. What does it mean when a frame is wide but has no wide children?
10. What does a flamegraph **not** show you at all?

Question 10 matters: a CPU profile shows on-CPU time. A process blocked on I/O
consumes no CPU and is nearly invisible — which is why off-CPU profiling exists
as a separate technique. Half of the interesting latency problems are off-CPU.

### Part 5 — compare against module 08

You now have three views of the same slow request:

| Source | What it tells you |
|---|---|
| Trace (module 08) | Which service and which span |
| Metric (module 07) | How often and how bad |
| Flamegraph (here) | **Which line of code** |

11. Walk the full path for one slow request: alert → metric → exemplar → trace →
    profile. Time it.
12. Which step would you not want to lose?

## Expected outcome

A flamegraph with an identified hot path, twelve questions answered, and the
full alert-to-line-of-code path walked once and timed.

## Verification

```bash
./platform/scripts/verify.sh profiling
```

## Staged hints

<details><summary>Hint 1 — question 1</summary>

99 Hz rather than 100 avoids sampling in lockstep with periodic kernel activity
that runs at round frequencies. Sampling at exactly the same rate as something
periodic gives you a systematically biased picture — the same aliasing problem as
in signal processing.
</details>

<details><summary>Hint 2 — question 9</summary>

A wide frame with no wide children means the time is spent **in that function
itself**, not in what it calls. That is where to optimise. A wide frame whose
width comes entirely from one child is just a passthrough — optimising it
achieves nothing.
</details>
