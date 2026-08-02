# Lab 05.06 — Standard versus experimental

**EXTEND · 40 min**

> Skip if behind schedule. Worth doing before you propose Gateway API for a
> production cluster.

## Context

The channel question used to be much bigger than it is now. As of v1.6, most of
what people historically needed the experimental channel for has graduated. Part
of this lab is establishing that for yourself rather than repeating advice
written in 2024.

## The problem

### Part 1 — diff the channels

```bash
curl -sL -o /tmp/standard.yaml \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
curl -sL -o /tmp/experimental.yaml \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/experimental-install.yaml

for f in /tmp/standard.yaml /tmp/experimental.yaml; do
  echo "== $f"
  grep -E '^  name: .*gateway.networking' "$f" | sort
done
```

Build a table: resource, channel, API version. Then answer:

1. Which resources are in experimental only?
2. Which resources are in **both** but with different fields? (Harder — you have
   to diff the schemas, not just the resource list.)
3. `GRPCRoute`, `TCPRoute`, `TLSRoute`, `UDPRoute`, `ReferenceGrant`,
   `BackendTLSPolicy` — which channel and which version, as of v1.6?

### Part 2 — the upgrade risk

Install experimental in a scratch cluster, create a resource using an
experimental-only field, then install the standard CRDs over it.

```bash
kind create cluster --name channel-test
# ... install experimental, create the resource, then apply standard-install.yaml
kubectl get <resource> -o yaml
```

4. What happened to the object?
5. What happened to the field?
6. Would you have been warned?

### Part 3 — the policy

Write, in `NOTAS.md`, the rule you would give a team:

- When is experimental acceptable?
- What has to be true before depending on an experimental field?
- How do you track when it graduates?

## Expected outcome

A channel table, a demonstrated upgrade hazard, and a written policy.

## Staged hints

<details><summary>Hint 1 — question 2</summary>

Resource lists are the easy half. Compare `spec.versions[].schema` between the
two files for the same resource. `yq` helps:
`yq '.spec.versions[].schema.openAPIV3Schema.properties.spec.properties | keys' `
on each. Fields present in one and not the other are the real risk, because the
resource *appears* supported.
</details>

<details><summary>Hint 2 — question 4</summary>

The object survives; the unrecognised field is silently dropped on the next
write. That silence is the hazard — no error, no warning, just configuration that
stops being applied. It is the same failure class as an ignored annotation, and
it is why this lab exists.
</details>

## Cleanup

```bash
kind delete cluster --name channel-test
rm -f /tmp/standard.yaml /tmp/experimental.yaml
```
