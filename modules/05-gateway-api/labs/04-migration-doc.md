# Lab 05.04 — The migration document

**CORE · 50 min**

## Context

This is the deliverable that matters most in the module. Not because writing
documents is the job, but because being able to justify a migration — including
its costs — is exactly what an architecture review tests, and it is the thing
that distinguishes "I used Gateway API" from "I chose Gateway API".

## The problem

Write `modules/05-gateway-api/MIGRATION.md`, in English, for an engineer who has
200 Ingresses and has been told to migrate. They are sceptical, and they are
right to be.

### Required sections

**1. Field mapping.** Every Ingress field to its Gateway API equivalent.

| Ingress | Gateway API | Notes |
|---|---|---|
| `spec.ingressClassName` | | |
| `spec.rules[].host` | | |
| `spec.rules[].http.paths[].path` | | |
| `pathType: Prefix` / `Exact` / `ImplementationSpecific` | | |
| `spec.tls[]` | | |
| `spec.defaultBackend` | | |

**2. Annotation inventory.** This is where the real work is. For the common
NGINX Ingress annotations, state the Gateway API equivalent or its absence:

`rewrite-target`, `ssl-redirect`, `proxy-body-size`, `proxy-read-timeout`,
`rate-limit`, `auth-url`, `canary`, `configuration-snippet`, `cors-allow-origin`

Three categories: direct equivalent · implementation-specific policy · no
equivalent, must move.

**3. What got harder.** Be specific and honest:
- More objects for the same result
- Cross-namespace routing now requires coordination between two teams
- Implementation-specific policy CRDs vary, so portability is partial in practice
- Smaller pool of engineers who know it

**4. What got better.** With evidence from your own labs, not marketing:
- Route attachment failures are reported in `status`, with a documented reason
- Traffic splitting is portable and specified
- Match precedence is specified, not controller-dependent
- Role separation is enforced by the API, not by convention

**5. Migration strategy.** Concrete and reversible:
- Run both in parallel on the same hostname
- Shift traffic gradually, with the rollback step written out
- Order: which Ingresses first, and why
- The stopping rule — what would make you abandon the migration

**6. The recommendation, including when not to migrate.**

## The section that gets you hired

Section 6 must include a defensible case for **not** migrating. For example: a
single-team cluster with fifteen Ingresses using only host and path routing, on a
controller nobody plans to change, has close to nothing to gain and real
retraining cost.

A migration document that only argues one way is advocacy. The one that names the
conditions under which its own recommendation is wrong is engineering.

## Expected outcome

`MIGRATION.md` complete, with the annotation table filled from your own testing
rather than copied.

## Staged hints

<details><summary>Hint 1 — rewrite-target</summary>

`URLRewrite` filter, portably. But the semantics are not identical: the NGINX
annotation takes a regex with capture groups, whereas `URLRewrite` supports
`ReplacePrefixMatch` and full path replacement. Regex rewrites do not map
cleanly — a genuine "must move" case and a good example for section 2.
</details>

<details><summary>Hint 2 — auth-url</summary>

External authentication has no standard Gateway API equivalent today. Options:
an implementation-specific policy, an ext_authz filter if the implementation is
Envoy-based, or moving authentication into the application or a mesh. This is
the annotation that most often blocks a migration in practice, so give it real
treatment.
</details>
