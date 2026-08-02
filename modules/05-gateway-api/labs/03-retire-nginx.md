# Lab 05.03 — Retire NGINX

**CORE · 60 min**

## Context

The capstone layer. Everything the NGINX config from module 02 did must now be
done by Gateway API — or consciously dropped, with a reason.

**Write the manifests from memory.** If you need the specification, note which
field sent you looking; that list goes straight into your 30-day review.

## The problem

### Part 1 — inventory what NGINX does

Before writing anything, list every behaviour in your module 02 config:

| NGINX behaviour | Gateway API equivalent | Or: how it moves |
|---|---|---|
| Route `/` → pulse-web | | |
| Route `/api` → pulse-api | | |
| TLS termination | | |
| HTTP → HTTPS redirect | | |
| Response caching | | |
| Rate limiting | | |
| `X-Forwarded-*` headers | | |
| Upstream timeouts | | |

Some have direct equivalents. Some are implementation-specific extensions. Some
have **no equivalent** and have to move elsewhere. Fill this in honestly — the
empty cells are the substance of lab 04's migration document.

### Part 2 — build it

1. TLS listener on 443 with the certificate from module 02.
2. HTTP listener on 80 with a `RequestRedirect` filter to HTTPS.
3. Path routing for `/api` and `/`.
4. A header-based route: `X-Pulse-Channel: beta` → a second `pulse-api`
   Deployment.

That fourth one is not decoration. Module 11 replaces the header match with a
weighted split, and the whole canary rests on it.

### Part 3 — delete NGINX

```bash
kubectl delete deployment,service,configmap -n pulse -l app=nginx-edge
```

Re-run the platform verification. The `nginx` group should now be replaced by a
`gateway` group — write it.

### Part 4 — what you lost

Caching and rate limiting have no portable Gateway API expression. Decide where
each goes and write it down:

- In the application?
- In an implementation-specific policy (and what does that cost in portability)?
- Dropped, because it was not earning its place?

There is no correct answer. There is a correct *process*, and it is what an
architecture review examines.

## Expected outcome

Pulse served entirely through Gateway API, NGINX gone, the inventory table
complete, and a written decision for each capability with no equivalent.

## Verification

```bash
kubectl get gateway,httproute -n pulse
./platform/scripts/verify.sh gateway
curl -H 'X-Pulse-Channel: beta' -H 'Host: pulse.local' localhost:8080/api/checks
```

## Staged hints

<details><summary>Hint 1 — HTTP to HTTPS redirect</summary>

A `RequestRedirect` filter on a route attached to the HTTP listener. It is a
route-level filter, not a Gateway setting — which is itself a difference worth
noticing: the redirect is a routing decision, so it lives with the routes.
</details>

<details><summary>Hint 2 — header matching</summary>

`matches[].headers[]` with `type: Exact`. Remember precedence: a rule with a
header match beats one without, for the same path. That is specified behaviour,
not implementation-dependent — so you can rely on it.
</details>
