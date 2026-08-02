# Refresher 31: Linux Performance Debugging — strace & perf

**Module:** 31 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

Three processes with three different problems, each needing a different tool.
Everything runs inside a container with `CAP_SYS_PTRACE`, so the lab needs no
root on the host.

```bash
./run-lab.sh
```

Evidence: [`01-diagnosis.txt`](./evidence/01-diagnosis.txt).

> `strace` needs `--cap-add=SYS_PTRACE` **and** `--security-opt seccomp=unconfined`.
> Docker drops the capability and the default seccomp profile blocks `ptrace`
> outright — miss either and strace fails with a permission error that looks
> like a kernel problem.

---

## Case A — a report job that is slow for reasons not in the code

**Symptom.** Writing 200,000 rows takes 0.6s. The code is a plain
`for` loop over `f.write()`. Nothing looks expensive.

**Diagnosis.** Count syscalls rather than reading them — `strace -c` summarises
instead of printing millions of lines:

```
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 99.62    6.292214          31    200001           write
  0.12    0.007660          31       245        24 newfstatat
  0.06    0.003545          59        60         8 openat
```

**200,001 `write` calls for 200,000 rows, and 99.62% of all syscall time.** One
kernel crossing per line, caused by a single `f.flush()` inside the loop.

**The key command.**

```bash
strace -c -f python3 report_writer.py
```

**The fix** is not faster code, it is fewer crossings — remove the per-line flush
and let the runtime buffer:

| | syscalls | wall clock (3 runs) |
|---|---|---|
| slow (`flush()` per line) | **200,720** | 0.626s / 0.612s / 0.610s |
| fast (buffered) | **1,473** | 0.074s / 0.094s / 0.076s |

136x fewer syscalls, **8x faster**, and the output files are byte-identical
(`cmp` confirms).

---

## Case B — a service that starts, logs "ready", and hangs

**Symptom.** Three log lines, then nothing. No CPU, no error, no exit.

**Diagnosis.**

```
    PID STAT %CPU %MEM     ELAPSED CMD
     64 S     0.0  0.0       00:03 python3 /work/stuck_service.py
```

State `S` with 0% CPU: sleeping inside a syscall. Not spinning, not crashed —
which already rules out a deadlock-by-busy-loop and any CPU profiler.

`/proc/PID/syscall` answers *which* syscall without attaching anything:

```
syscall: 257 0xffffff9c 0x7fc9de62c8d0 0x80000 ...
wchan:   wait_for_partner
```

Syscall `257` on x86-64 is `openat`. And `wchan` — the kernel function the task
is parked in — is literally `wait_for_partner`: the kernel's name for a FIFO
waiting for its other end.

`strace` confirms it, and shows the call **unfinished** because the process is
parked inside it rather than passing through it:

```
strace: Process 64 attached
openat(AT_FDCWD, "/tmp/orders.fifo", O_RDONLY|O_CLOEXEC
 <detached ...>
```

No closing parenthesis, no return value. `/proc/PID/fd` then proves it never got
the file open at all:

```
0 -> /dev/null
1 -> /tmp/stuck.log
2 -> /tmp/stuck.log
```

Only stdio. The FIFO is absent, so the process is blocked *in* the open, not
reading from it.

**The key command.**

```bash
cat /proc/<pid>/syscall && cat /proc/<pid>/wchan
```

**Proof.** Give it a writer and it moves on immediately:

```
$ echo 'order-1' > /tmp/orders.fifo
processed: order-1
upstream closed
```

---

## Case C — slow, and strace finds nothing

**Symptom.** Pricing 140 orders takes 0.94s.

**Diagnosis.** Same first move as case A:

```
100.00    0.016673          23       711        75 total
   0.02    0.000003           3         1           write
```

**711 syscalls total, almost all interpreter startup, and a single `write`.**

That emptiness *is* the finding. A process making no syscalls is not waiting on
the kernel — not disk, not network, not a lock, not a slow dependency. It is
burning CPU in user space, and strace has nothing further to offer.

`perf stat` confirms it in one line:

```
        1014.20 msec task-clock:u              #    1.058 CPUs utilized
              0      context-switches:u
   0.958582905 seconds time elapsed
   1.015323000 seconds user
   0.000000000 seconds sys        <-- zero kernel time
```

**Zero seconds of system time and zero context switches.** Entirely user-space
CPU.

```bash
perf record -F 499 -g python3 pricing_engine.py && perf report --stdio
```

```
# Samples: 515  of event 'cycles:u'
    53.70%     0.00%  [.] 0x0000000000959cc0
            |--18.41%--_PyEval_EvalFrameDefault
```

`perf` points at the CPython interpreter loop — **correct and useless**. Every
Python function is `_PyEval_EvalFrameDefault` to a native profiler, because the
Python call stack lives in interpreter data structures, not in CPU frames. A
runtime-aware profiler is needed to go further:

```
   ncalls  tottime  cumtime  filename:lineno(function)
      140    0.899    0.899  pricing_engine.py:18(check_fraud_score)
      140    0.000    0.000  pricing_engine.py:12(apply_discount)
```

`check_fraud_score` — 0.899s of 0.94s.

---

## Issues encountered

**`pgrep -f` matched its own shell and returned two PIDs.** The first version of
case B used `pgrep -f stuck_service.py`. The `sh -c` wrapper running that
command has the pattern in *its* command line, so pgrep matched both, `$PID`
became `"64\n73"`, and strace failed with `Can't stat '73'`. Every subsequent
`/proc/$PID/...` read silently returned the wrong thing — `ls` printed a
directory listing that looked plausible and was not what was asked for.

Fixed by capturing `$!` at launch and writing it to a file. `pgrep -f` self-
matching is a well-known trap and it produced a *wrong answer* rather than an
error, which is the more expensive failure.

**`strace -c` output is sorted by cost, so the answer is at the top.** The first
run filtered it with `tail -18` and cut off the `write` row entirely — the one
line carrying 99.62% of the time. The total was visible; the cause was not.

---

## What I re-learned

- **The absence of syscalls is a diagnosis, not a dead end.** Case C's empty
  strace output rules out disk, network, locks and dependencies in a single
  command, and points straight at profiling. "strace found nothing" is a
  narrowed search, and it took under a second.

- **`/proc/<pid>/wchan` names the wait, and often names it exactly.**
  `wait_for_partner` described the bug more precisely than the application logs
  did. `wchan` and `/proc/<pid>/syscall` are read-only, need no attach, cannot
  perturb the process, and work on something already blocked — strace attaches
  and shows nothing until the syscall *returns*, which on a hung process is
  never.

- **An unfinished strace line is information.** `openat(...` with no closing
  paren means "parked inside this call". It is the difference between a syscall
  being slow and a syscall never returning.

- **A native profiler cannot see through a runtime.** `perf` was right that the
  time was in `_PyEval_EvalFrameDefault` and that was useless. Knowing when to
  switch from a system tool to a runtime-aware one is the actual skill; the
  same applies to JVM, Node and Go stacks.

- **The fix for a syscall storm is architectural, not micro-optimisation.**
  200,001 writes became 1,473 by deleting one line. No algorithm changed, the
  output is byte-identical, and it ran 8x faster. The cost was at a boundary the
  source code does not show.
