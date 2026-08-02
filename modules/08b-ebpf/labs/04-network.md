# Lab 08b.04 — Below the application

**CORE · 50 min**

## Context

This lab builds the tooling that would have caught this module's break-fix. Do
the break-fix first — diagnosing it cold is worth more.

## The problem

### Part 1 — the queues before your code

```bash
# In LISTEN state these columns mean something different than usual:
#   Recv-Q = established connections waiting for accept()
#   Send-Q = maximum size of that queue
ss -ltn

sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog
nstat -az | grep -iE 'listen|syn|retrans'
```

1. What is the accept queue size for `pulse-api`? Where did that number come
   from — the application, or the kernel?
2. What happens to a connection when that queue is full? What does the client
   see?

### Part 2 — measure accept latency

The metric your application cannot produce about itself:

```bash
bpftrace -e '
kprobe:inet_csk_accept { @start[tid] = nsecs; }
kretprobe:inet_csk_accept /@start[tid]/ {
  @accept_us = hist((nsecs - @start[tid]) / 1000);
  delete(@start[tid]);
}'
```

Then overload it deliberately:

```bash
kubectl run flood --image=busybox -n pulse --restart=Never -- \
  sh -c 'for i in $(seq 500); do wget -qO- -T1 http://pulse-api:8080/healthz >/dev/null 2>&1 & done; wait'
```

3. What happens to the histogram?
4. What happens to `TcpExtListenOverflows`?
5. **What does the application's own p99 metric say during this?** Compare it
   against what the client experiences. This is the whole point.

### Part 3 — retransmits

```bash
bpftrace -e '
tracepoint:tcp:tcp_retransmit_skb {
  printf("retransmit %s\n", comm);
  @retrans[comm] = count();
}'
```

6. Retransmits during the flood: how many, and why do they explain multi-second
   client latency when the server is fast?
7. What are the default retransmission timeouts? Do they match the delays you
   observe?

### Part 4 — flows without a mesh

Deploy Hubble (or Cilium with Hubble) and observe service-to-service traffic.

8. Can you see the `pulse-worker` → `pulse-api` calls without either service
   being instrumented?
9. What does this give you that the traces from module 08 do not?
10. What do the traces give you that this does not?

Question 10 has a specific answer: flows show you *that* A talked to B and how
much; traces show you *why*, and which user request caused it.

### Part 5 — export it

Turn the accept-latency histogram into a Prometheus metric, and write the alert
that would have caught the break-fix:

```promql
rate(node_netstat_TcpExt_ListenOverflows[5m]) > 0
```

11. `node-exporter` already exposes this. Was it there all along?
12. Why does nobody look at it?

The honest answer to 12 is worth writing down: default dashboards show CPU,
memory and disk. Nothing prompts you to look at TCP counters until you already
know that is where the problem is — which is exactly the trap.

## Expected outcome

Accept-latency histogram under load, the application/client latency discrepancy
demonstrated, flow visibility without instrumentation, and a working alert.

## Staged hints

<details><summary>Hint 1 — question 5</summary>

The application reports the same fast p99 as always. It is not lying: it really
did serve each request in 40 ms — measured from the moment it accepted the
connection. The waiting happened before that, and no instrumentation inside the
process can see it.
</details>

<details><summary>Hint 2 — question 7</summary>

Initial RTO is around 1s, then it doubles: 1, 3, 7, 15. A client that lost its
connection to a full accept queue waits for the first retransmit, which alone
accounts for a multi-second delay. The pattern of client latencies clustering
around those values is itself a diagnostic signature.
</details>

## Cleanup

```bash
kubectl delete pod flood load -n pulse --ignore-not-found
```
