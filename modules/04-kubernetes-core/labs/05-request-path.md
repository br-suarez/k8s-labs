# Lab 04.05 — Trace a request end to end

**EXTEND · 45 min**

> Skip if behind schedule. Come back before module 05 — Gateway API debugging is
> much easier once you can see the whole path.

## Context

"The Service routes to the pod" is an abstraction. This lab replaces it with the
actual mechanism, so that when routing breaks you know which of six components to
inspect.

## The problem

Follow a single request from outside the cluster to the process, naming and
inspecting every hop.

### The chain

```
client → node port → kube-proxy rules → pod IP → container port → process
```

For each hop, find the concrete artefact:

1. **Service** — `kubectl get svc pulse-api -n pulse -o yaml`. What is the
   ClusterIP? Is it real? Can you ping it? Why not?

2. **EndpointSlice** — `kubectl get endpointslice -n pulse`. Which pod IPs are
   listed? Compare against `kubectl get pods -o wide`. Now scale to 0 and look
   again.

3. **kube-proxy rules** — on the node:
   ```bash
   docker exec pulse-lite-worker iptables-save -t nat | grep pulse-api
   ```
   Find the rule chain. How is load balancing actually implemented? What
   probability values do you see, and why are they not all equal?

4. **DNS** — 
   ```bash
   kubectl exec -n pulse deploy/pulse-worker -- nslookup pulse-api
   kubectl exec -n pulse deploy/pulse-worker -- cat /etc/resolv.conf
   ```
   Explain `ndots:5` and what it costs.

5. **The container** — `kubectl exec ... -- ss -tlnp` (if the image allows), or
   from the node: `docker exec <node> crictl inspect ...`.

## Questions

Answer in `NOTAS.md`:

1. Why can you not ping a ClusterIP?
2. If a pod is `Running` but missing from the EndpointSlice, what are the two
   most likely causes?
3. `ndots:5` means a lookup for `example.com` tries several search domains
   first. How many extra DNS queries does resolving an external name cost, and
   how would you avoid it?
4. Where exactly does traffic go during the 2-second window in which a pod is in
   the EndpointSlice but not ready?

## Expected outcome

A diagram in `NOTAS.md` with all six hops, the command that inspects each, and
the failure mode each hop can produce.

That diagram is the thing you will actually reuse — in module 05 when an
`HTTPRoute` gets no traffic, and in module 16 when a Game Day failure is
injected into the network layer.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

A ClusterIP is not assigned to any interface. It exists only as a match in
iptables/IPVS rules that rewrite the destination. There is nothing to reply to
ICMP — the address is a rule, not a host.
</details>

<details><summary>Hint 2 — question 3</summary>

With `ndots:5`, any name with fewer than 5 dots is tried against each search
domain first. `example.com` becomes `example.com.pulse.svc.cluster.local`,
`example.com.svc.cluster.local`, `example.com.cluster.local`, and only then
`example.com`. Four to six queries for one external lookup. Fix with a trailing
dot (`example.com.`) or a custom `dnsConfig` — and note this is a real,
measurable latency source in outbound-heavy services like `pulse-worker`.
</details>
