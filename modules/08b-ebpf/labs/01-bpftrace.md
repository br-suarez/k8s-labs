# Lab 08b.01 — Trace a process you cannot touch

**CORE · 55 min**

## Context

The constraint is the lab: a running Pulse pod that you may not restart,
recompile or add logging to. Everything you learn has to come from outside, while
it keeps serving.

## Setup

`bpftrace` needs kernel headers and privileges. On kind, the simplest path is a
privileged pod on the node:

```bash
kubectl run bpftrace --rm -it --restart=Never \
  --image=quay.io/iovisor/bpftrace:latest \
  --overrides='{"spec":{"hostPID":true,"containers":[{"name":"bpftrace",
    "image":"quay.io/iovisor/bpftrace:latest","stdin":true,"tty":true,
    "securityContext":{"privileged":true},
    "volumeMounts":[{"name":"sys","mountPath":"/sys"},{"name":"mod","mountPath":"/lib/modules"}]}],
    "volumes":[{"name":"sys","hostPath":{"path":"/sys"}},{"name":"mod","hostPath":{"path":"/lib/modules"}}]}}' \
  -- /bin/sh
```

`hostPID: true` is what lets you see the other containers' processes. Note in
`NOTAS.md` exactly which privileges you needed and why — question 9 of
`PREGUNTAS.md` is about that.

If it will not run on your kernel, record it and use the host WSL kernel
directly. Some of the labs work either way.

## The problem

### Part 1 — orient yourself

```bash
bpftrace -l 'tracepoint:syscalls:*' | head -30
bpftrace -l 'tracepoint:tcp:*'
```

1. What is the difference between the `tracepoint:` and `kprobe:` namespaces in
   that listing?
2. Roughly how many probes does your kernel expose?

### Part 2 — what is it doing?

Find the PID of `pulse-worker` on the node, then answer each question with a
one-liner. Write the question first, then the probe.

```bash
# Which syscalls dominate?
bpftrace -e 'tracepoint:raw_syscalls:sys_enter /pid == PID/ { @[args->id] = count(); }'

# What files does it open?
bpftrace -e 'tracepoint:syscalls:sys_enter_openat /pid == PID/ { printf("%s\n", str(args->filename)); }'

# Where is it connecting?
bpftrace -e 'kprobe:tcp_connect { printf("%s -> connect\n", comm); }'

# Distribution of read sizes
bpftrace -e 'tracepoint:syscalls:sys_exit_read /pid == PID/ { @bytes = hist(args->ret); }'
```

3. Which syscall dominates, and does it match what you know the worker does?
4. Does it open any file you did not expect?
5. Compare against `strace -c -p PID` for ten seconds. Same answer? Same impact
   on the process?

Question 5 is the one that justifies the tool.

### Part 3 — measure something no metric gives you

Latency distribution of the `write` syscall, in microseconds:

```bash
bpftrace -e '
tracepoint:syscalls:sys_enter_write /pid == PID/ { @start[tid] = nsecs; }
tracepoint:syscalls:sys_exit_write /@start[tid]/ {
  @us = hist((nsecs - @start[tid]) / 1000);
  delete(@start[tid]);
}'
```

6. What shape is the distribution? Is it bimodal? What would a second peak mean?
7. Could you have obtained this from OpenTelemetry? What would it have cost?

### Part 4 — write your own

Answer a question about Pulse that no existing tool answers. Suggestions:

- How long does `pulse-worker` spend blocked on the network versus computing?
- Which DNS names does it resolve, and how long does each take?
- What is the size distribution of the responses it receives?

Write the probe, run it, record the output.

## Expected outcome

Seven questions answered, plus one probe of your own with real output.

## Staged hints

<details><summary>Hint 1 — finding the PID from outside the container</summary>

With `hostPID: true` you see the host PID namespace, so `ps aux | grep pulse`
works from the bpftrace pod. From the node:
`crictl inspect $(crictl ps -q --name pulse-worker) | jq '.info.pid'`.
</details>

<details><summary>Hint 2 — question 5</summary>

`strace` stops the process at every syscall via ptrace: two context switches per
call. On a busy process that is a large slowdown, and it has caused production
incidents. bpftrace runs the filter in the kernel and only surfaces aggregates —
nanoseconds per event, no ptrace. Measure the request rate during both to see it
rather than take my word for it.
</details>
