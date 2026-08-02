# Module 05 — Gateway API

**6 blocks.** Requires modules 02 and 04. One of the heaviest modules in the
track.

**None of the reference lab repositories cover this at all.** Every one of them
uses Ingress. This module is built from scratch against the upstream
specification, and it is weighted accordingly.

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
| 00 | Repaso (módulos 03–04) | CORE | 15 min |
| 01 | Install Gateway API CRDs (v1.6.1, standard channel) and a controller; explain what the CRDs alone do and do not give you | CORE | 40 min |
| 02 | First Gateway and HTTPRoute from the spec — documentation open, this once | CORE | 50 min |
| 03 | Path and header routing for Pulse; retire the NGINX config from module 02 | CORE | 60 min |
| 04 | **The migration document** — every Ingress field mapped to its Gateway equivalent, and the ones with none | CORE | 50 min |
| 05 | Traffic splitting by weight — the mechanism module 11's canary is built on | CORE | 45 min |
| 06 | Standard vs experimental channel: what is in each, and the risk of depending on experimental | EXTEND | 40 min |
| 07 | `ReferenceGrant` and cross-namespace routing | EXTEND | 40 min |
| 08 | Request mirroring to a shadow backend | DEEP | 30 min |

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
