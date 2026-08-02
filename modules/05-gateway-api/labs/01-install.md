# Lab 05.01 — CRDs and a controller

**CORE · 40 min**

## Context

Gateway API ships as CRDs plus a separate controller. Understanding that split is
the first thing, because installing the CRDs and expecting traffic to flow is the
most common initial confusion.

## The problem

### Part 1 — CRDs alone

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
kubectl get crd | grep gateway.networking
```

Now create a Gateway and watch nothing happen:

```bash
kubectl create namespace pulse-gw
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: orphan
  namespace: pulse-gw
spec:
  gatewayClassName: nonexistent
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl describe gateway orphan -n pulse-gw
```

Answer in `NOTAS.md`:

1. What does the status say, and what is the `Reason`?
2. What exactly did the CRDs give you? What are they *not* giving you?
3. Compare with Ingress: what happens when you create an Ingress with no
   controller installed?

### Part 2 — what is in the standard channel

Inspect what you installed:

```bash
kubectl get crd -o custom-columns=\
'NAME:.metadata.name,VERSIONS:.spec.versions[*].name' | grep gateway.networking
```

As of v1.6, `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute`, `TCPRoute`,
`TLSRoute`, `UDPRoute`, `ReferenceGrant` and `BackendTLSPolicy` are all at `v1`
in the standard channel. Record which versions you actually see — the point is to
build the habit of checking rather than trusting a blog post.

### Part 3 — install a controller

Install an implementation. Envoy Gateway or NGINX Gateway Fabric both work; pick
one and note why.

Then:

```bash
kubectl get gatewayclass
kubectl describe gatewayclass <name>
```

4. Who created the GatewayClass — you, or the controller?
5. What does `Accepted: True` on a GatewayClass mean?

## Expected outcome

A working GatewayClass, and the five questions answered. Delete the orphan
Gateway when done.

## Staged hints

<details><summary>Hint 1 — question 3</summary>

An Ingress with no controller sits there with an empty `status.loadBalancer` and
no explanation. Gateway API gives you an explicit condition with a reason
(`InvalidGatewayClass` / `Pending`). That difference in feedback quality is a
recurring theme of this module.
</details>

## Cleanup

```bash
kubectl delete gateway orphan -n pulse-gw --ignore-not-found
kubectl delete namespace pulse-gw --ignore-not-found
```
