# Lab 01.02 — Reading a process from outside

**CORE · 60 min**

## Context

The process is misbehaving. You cannot attach a debugger, you cannot add logging,
you cannot restart it — restarting destroys the evidence. Everything you learn
has to come from outside.

## The problem

Three scenarios. For each: **write your hypothesis before running anything**,
then prove or disprove it.

### Scenario A — the spinner

```bash
bash -c 'while :; do :; done' &
```

Determine: is it doing real work? Where is the time going? Why does `strace`
tell you nothing, and what do you use instead?

### Scenario B — the blocked process

```bash
mkfifo /tmp/lab-pipe
cat /tmp/lab-pipe &
```

Determine: what is it blocked on, without knowing it is a FIFO? Which file in
`/proc/<pid>/` answers this in one read?

### Scenario C — the syscall storm

```bash
bash -c 'while :; do echo x > /dev/null; done' &
```

Determine: how many syscalls per second, which one dominates, and how would you
reduce it? Compare against scenario A — both are at 100% CPU and the diagnosis is
completely different.

## The command set

Use each at least once and record what it told you that the others did not:

| Command | Answers |
|---|---|
| `top -H -p <pid>` | Is it one thread or all of them? |
| `cat /proc/<pid>/wchan` | What kernel function is it sleeping in? |
| `cat /proc/<pid>/stack` | Full kernel stack (needs root) |
| `cat /proc/<pid>/status` | State, threads, memory, context switches |
| `strace -c -p <pid>` | Syscall counts — **run for a bounded time** |
| `lsof -p <pid>` | Open files, sockets, pipes |
| `perf top -p <pid>` | Where user-space CPU actually goes |

## Expected outcome

A table in `NOTAS.md`:

| Scenario | Hypothesis | Command that confirmed it | What I got wrong |
|---|---|---|---|

The last column is the point of the lab.

## Verification

Self-assessed. You pass if, for scenario A, you can explain **why an empty
`strace -c` output is itself the diagnosis**.

## Staged hints

<details><summary>Hint 1 — scenario A</summary>

`strace` traces syscalls. A pure user-space loop makes none. Zero output is not a
broken tool; it is evidence, and it rules out an entire class of causes.
</details>

<details><summary>Hint 2 — scenario B</summary>

`/proc/<pid>/wchan` names the kernel function the process is sleeping in. Compare
with `/proc/<pid>/status` field `State:` — `S` (interruptible) versus `D`
(uninterruptible) is the difference between "waiting politely" and "stuck in I/O
and not even killable".
</details>

<details><summary>Hint 3 — bounding strace</summary>

`strace -c -p <pid>` runs until you interrupt it. Use `timeout 5 strace -c -p
<pid>`, and be aware strace slows the target substantially — on a busy production
process that alone can cause an incident.
</details>

## Cleanup

```bash
kill %1 2>/dev/null; rm -f /tmp/lab-pipe
```

## Note

If you completed `archive/sre-track/31-linux-performance/`, this is deliberately
familiar. Do it anyway, timed, and compare against your notes from then — the
gap between what you knew and what you retained is the most useful measurement
in the whole track.
