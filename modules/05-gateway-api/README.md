# Module 05 — Gateway API

**5 blocks CORE**, plus 3 optional labs. Requires modules 02 and 04.

Weighted heavily because it is written from the upstream specification rather
than adapted from existing material — but deliberately trimmed from 6 to 5,
because Ingress still dominates the installed base and this is an investment in
where routing is going rather than where it is. Labs 06, 07 and 08 are genuinely
optional; the CORE path is 00–05.

The two things that keep it at 5 rather than lower: lab 05 is load-bearing for
module 11's canary, and the migration document in lab 04 is the strongest
interview artifact this track produces.

## Objectives

1. Implement Gateway API from the specification, not from a tutorial.
2. Migrate a working Ingress-based edge to Gateway API and articulate what
   improved and what got harder.
3. Use the role separation the API was designed around — infrastructure provider,
   cluster operator, application developer — and explain why it exists.
4. Route by path, header and weight, and know which of those Ingress could not
   do portably.

## Exit criteria

- [ ] I can write a `GatewayClass`, `Gateway` and `HTTPRoute` from memory that
      routes two backends by path and one by header.
- [ ] I can migrate an Ingress to an `HTTPRoute` and explain every field that has
      no direct equivalent.
- [ ] Given an `HTTPRoute` not receiving traffic, I can diagnose it from status
      conditions — and I know the four places the failure can hide.
- [ ] I can defend Gateway API against Ingress-plus-annotations and against a
      service mesh, and state when I would choose each.

## Correctness note

**Ingress is not deprecated.** It is feature-frozen at `networking.k8s.io/v1`;
Gateway API is its designated successor. Saying "deprecated" in an architecture
review gets you corrected. The accurate framing is: Ingress is stable and
maintained, no new capability is being added to it, and portable expression of
anything beyond host/path routing requires vendor-specific annotations — which is
the actual problem Gateway API solves.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) (módulos 03–04) | CORE | 15 min |
| 01 | [CRDs and a controller](./labs/01-install.md) (v1.6.1, standard channel) — what the CRDs alone do and do not give you | CORE | 40 min |
| 02 | [First Gateway and HTTPRoute](./labs/02-first-route.md) — documentation open, this once | CORE | 50 min |
| 03 | [Retire NGINX](./labs/03-retire-nginx.md) — path and header routing for Pulse | CORE | 60 min |
| 04 | [**The migration document**](./labs/04-migration-doc.md) — every Ingress field and annotation mapped, including the ones with no equivalent | CORE | 50 min |
| 05 | [Traffic splitting by weight](./labs/05-traffic-splitting.md) — the mechanism module 11's canary is built on | CORE | 45 min |
| 06 | [Standard vs experimental channel](./labs/06-channels.md) and the upgrade hazard | EXTEND | 40 min |
| 07 | [`ReferenceGrant` and cross-namespace routing](./labs/07-cross-namespace.md) | EXTEND | 40 min |
| 08 | [Request mirroring to a shadow backend](./labs/08-mirroring.md) | DEEP | 30 min |

> Labs 00–05 are the 5 CORE blocks. Labs 06–08 are optional and the first thing
> to drop if you are behind — pick them up in a reserve week. Note that lab 07
> constructs this module's break-fix forwards, so do the break-fix first.

> **Channel note (verified 2026-08-02).** As of v1.6, `GatewayClass`, `Gateway`,
> `HTTPRoute`, `GRPCRoute`, `TCPRoute`, `TLSRoute`, `UDPRoute`, `ReferenceGrant`
> and `BackendTLSPolicy` are all at `v1` in the **standard** channel —
> `BackendTLSPolicy` has been GA since v1.4. Guidance written before 2025 tends
> to assume far more lives in experimental than actually does. Check the CRDs you
> installed rather than trusting a blog post; lab 01 has you do exactly that.

## Capstone layer

NGINX is **removed**. Pulse is served entirely through Gateway API:

- `/` → pulse-web
- `/api` → pulse-api
- `X-Pulse-Channel: beta` header → a second pulse-api deployment

That header route is not decoration: module 11 replaces it with a weighted split
for canary analysis.

## The deliverable that matters

`MIGRATION.md` — Ingress to Gateway API, written for someone who has to make this
decision on a real cluster. Include what got harder, not only what improved. A
migration document that only lists benefits is marketing, and it will not survive
an architecture review.

## Verification

```bash
kubectl get gateway,httproute -n pulse
./platform/scripts/verify.sh gateway
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
