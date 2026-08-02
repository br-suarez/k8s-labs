# Lab 05.07 — ReferenceGrant and cross-namespace routing

**EXTEND · 40 min**

> This is the break-fix scenario, built forwards. Do the break-fix **first** if
> you have not — diagnosing it cold is worth more than constructing it.

## Context

Cross-namespace routing is where Gateway API's security model becomes visible,
and where teams first hit a wall that Ingress never put in front of them.

## The problem

### Part 1 — build the multi-team setup

```bash
kubectl create namespace pulse-platform    # owns the Gateway
kubectl create namespace pulse-frontend    # owns pulse-web
kubectl create namespace pulse-backend     # owns pulse-api
```

Move each component to its namespace. Gateway in `pulse-platform`, with
`allowedRoutes.namespaces.from: Same`.

Now try to route from the other two. Both fail. Record the exact conditions.

### Part 2 — grant access, two ways

**Option A — `from: All`.** Try it, confirm it works, then explain in `NOTAS.md`
exactly what you just allowed. Who can now attach to your production gateway?

**Option B — `from: Selector` with a label.** Implement it. Label only the
namespaces that should have access.

Keep B.

### Part 3 — ReferenceGrant

Now put the `HTTPRoute` for `pulse-web` in `pulse-platform` while the Service
stays in `pulse-frontend`. The backendRef now crosses a namespace.

1. What condition fails, and with what reason?
2. Write the `ReferenceGrant`. Which namespace does it go in, and why that one?
3. Can it be scoped to a single Service by name? Do it.
4. Delete the `ReferenceGrant` while traffic is flowing. What happens, and how
   fast?

### Part 4 — the RBAC question

Answer in `NOTAS.md`:

5. Someone with full admin on `pulse-frontend` and nothing else — can they expose
   a service through the platform gateway on their own?
6. Can they route traffic to a Service in `pulse-backend`?
7. How does this compare with what the same person could do with Ingress?

Question 7 is the point of the whole lab.

## Expected outcome

Three-namespace setup working with least privilege, `ReferenceGrant` scoped to a
named Service, and the seven questions answered.

## Staged hints

<details><summary>Hint 1 — which namespace holds the grant</summary>

The **target** namespace — where the Service being referenced lives. The model is
consent from the resource owner: the party being referenced grants permission,
never the party requesting it. If it worked the other way it would authorise
nothing.
</details>

<details><summary>Hint 2 — question 7</summary>

With Ingress, that person creates an Ingress in their namespace naming any
backend, and most controllers will happily route it — cross-namespace backends
included, depending on the controller. There is no consent mechanism, so
namespace boundaries are advisory at the routing layer. That is the gap Gateway
API closes, and it is the strongest security argument in your migration
document.
</details>
