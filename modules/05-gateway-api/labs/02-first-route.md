# Lab 05.02 — First Gateway and HTTPRoute

**CORE · 50 min**

> The only lab in this module where you may keep the specification open. From
> lab 03 onwards, you write from memory.

## Context

Build the minimum that routes real traffic, and read the status of every object
as you go — that habit is what makes the rest of the module easy.

## The problem

### Part 1 — the Gateway

Write a `Gateway` in the `pulse` namespace with:

- An HTTP listener on port 80
- Hostname `pulse.local`
- `allowedRoutes` restricted to the same namespace (the safe default)

Apply it, then read the status **before** creating any route:

```bash
kubectl describe gateway pulse-gateway -n pulse
```

Record the conditions. Note that `Programmed: True` with zero routes still
returns 404 for everything — a Gateway is not a route.

### Part 2 — the HTTPRoute

Route `/api` to `pulse-api:8080`, everything else to `pulse-web:80`.

Then verify:

```bash
# Find the gateway address
kubectl get gateway pulse-gateway -n pulse \
  -o jsonpath='{.status.addresses[0].value}'

# On kind, port-forward the gateway's Service
kubectl port-forward -n <gw-namespace> svc/<gateway-svc> 8080:80 &

curl -H 'Host: pulse.local' localhost:8080/api/checks
curl -H 'Host: pulse.local' localhost:8080/
```

### Part 3 — break it on purpose, four ways

Reproduce each failure, record the exact condition and `Reason`, then fix it.
This table is the debugging reference you will use for the rest of your career
with this API.

| Break | Condition that reports it | Reason |
|---|---|---|
| Wrong `parentRefs.name` | | |
| Backend Service does not exist | | |
| Hostname on route does not intersect listener | | |
| `allowedRoutes` excludes the route's namespace | | |

Fill in the table from what you actually observe, not from documentation.

## Expected outcome

Traffic routed by path, and a completed four-row failure table in `NOTAS.md`.

## Verification

```bash
kubectl get httproute -n pulse -o custom-columns=\
'NAME:.metadata.name,ACCEPTED:.status.parents[0].conditions[?(@.type=="Accepted")].status,RESOLVED:.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status'
```

Both columns `True`.

## Staged hints

<details><summary>Hint 1 — reaching the Gateway on kind</summary>

The Gateway's address is usually a Service of type LoadBalancer, which stays
`Pending` on kind with no load balancer. Either port-forward its Service, or
install `cloud-provider-kind` / MetalLB. Port-forward is enough for this module
and avoids a dependency.
</details>

<details><summary>Hint 2 — the hostname intersection rule</summary>

If the listener sets a hostname and the route sets a hostname, they must
intersect. A route with no hostname inherits the listener's. A route whose
hostname does not intersect is accepted but matches nothing — one of the more
confusing failure modes, because `Accepted: True` looks fine.
</details>
