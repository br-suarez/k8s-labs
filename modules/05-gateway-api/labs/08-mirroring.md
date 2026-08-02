# Lab 05.08 — Request mirroring

**DEEP · 30 min**

> Optional. Do it in a reserve week. It is the safest way to test a risky change
> that exists, and almost nobody knows the feature is there.

## Context

Mirroring sends a copy of live traffic to a second backend and **discards the
response**. The shadow backend can fail, be slow, or return garbage without any
user noticing.

## The problem

### Part 1 — mirror to a shadow

```yaml
rules:
  - matches:
      - path:
          type: PathPrefix
          value: /api
    filters:
      - type: RequestMirror
        requestMirror:
          backendRef:
            name: pulse-api-shadow
            port: 8080
    backendRefs:
      - name: pulse-api
        port: 8080
```

Deploy `pulse-api-shadow` as a separate Deployment. Send traffic and confirm both
receive it:

```bash
kubectl logs -n pulse deploy/pulse-api --tail=20
kubectl logs -n pulse deploy/pulse-api-shadow --tail=20
```

### Part 2 — prove it is safe

Break the shadow, deliberately and thoroughly:

```bash
kubectl scale deployment pulse-api-shadow -n pulse --replicas=0
```

Confirm users see nothing. Then make it slow rather than absent — a shadow that
takes 30s to respond is a more interesting test than one that is down:

```bash
kubectl set env deployment/pulse-api-shadow -n pulse ARTIFICIAL_DELAY=30s
```

Measure client-observed latency during both. Record the numbers.

### Part 3 — the limits

Answer in `NOTAS.md`:

1. What happens to a mirrored request that is a `POST` with side effects? Why is
   this the single biggest constraint on mirroring?
2. Does the mirror get a copy of the request body? What does that cost?
3. Can you mirror a percentage rather than all traffic? Check the specification
   version you have installed rather than assuming.
4. What can mirroring test that a canary cannot? What can a canary test that
   mirroring cannot?

## Expected outcome

Working mirror, evidence that shadow failure is invisible to users, and the four
questions answered.

## Staged hints

<details><summary>Hint 1 — question 1</summary>

The mirror executes the request for real. A mirrored `POST /api/checks` creates a
second check. Anything with side effects gets duplicated — writes, emails,
payments. This is why mirroring is usually restricted to idempotent reads, or why
the shadow environment gets its own isolated datastore.
</details>

<details><summary>Hint 2 — question 4</summary>

Mirroring tests correctness and performance under **real traffic shape** with
zero user risk, but it cannot tell you anything about user-visible behaviour
because the response is thrown away. A canary tests the real response but exposes
real users. They are complementary: mirror first to catch crashes and latency
regressions, then canary to validate the response.
</details>

## Cleanup

```bash
kubectl delete deployment,service pulse-api-shadow -n pulse --ignore-not-found
```
