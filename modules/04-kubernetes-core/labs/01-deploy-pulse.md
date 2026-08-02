# Lab 04.01 — Deploy Pulse from scratch

**CORE · 50 min**

## Context

The capstone moves from Compose to Kubernetes. Write the manifests yourself —
`kubectl create ... --dry-run=client -o yaml` is allowed as a starting skeleton,
but every field you keep you must be able to justify.

## The problem

Fresh cluster:

```bash
kind create cluster --config platform/deploy/clusters/lite.yaml
```

Create `platform/deploy/k8s/` with manifests for the whole platform:

| Resource | For |
|---|---|
| Namespace | `pulse` |
| Deployment ×3 | `pulse-api`, `pulse-worker`, `pulse-web` |
| Service ×3 | ClusterIP for each |
| ConfigMap | non-secret config: intervals, concurrency, queue size |
| Secret | a placeholder credential, consumed as env |

Requirements:

1. `pulse-worker` reaches `pulse-api` **by Service DNS**, not by IP.
2. Probes on every service, each pointing at the correct endpoint.
3. Requests and limits on every container, chosen deliberately — reuse the
   numbers you measured in module 03 lab 04.
4. No image tags. Digests only.
5. Nothing runs as root.
6. `kubectl apply -f platform/deploy/k8s/` from empty to fully running, no manual
   steps, no ordering requirements.

## Expected outcome

```bash
kubectl get pods -n pulse
# all Running, all READY n/n, 0 restarts

kubectl exec -n pulse deploy/pulse-worker -- \
  wget -qO- http://pulse-api:8080/api/checks     # Service DNS resolves
```

## Verification

```bash
./platform/scripts/verify.sh k8s
```

## Staged hints

<details><summary>Hint 1 — Service DNS</summary>

Within a namespace, `http://pulse-api:8080`. Across namespaces,
`http://pulse-api.pulse.svc.cluster.local:8080`. Set it via the ConfigMap, not
hardcoded in the image — module 10 changes it per overlay and you do not want to
rebuild an image to do that.
</details>

<details><summary>Hint 2 — probes on a distroless image</summary>

Unlike Docker's `HEALTHCHECK`, Kubernetes `httpGet` probes are executed by the
kubelet from outside the container. Nothing needs to exist inside the image. This
is a genuine advantage of Kubernetes probes over Docker healthchecks and worth
noting in `NOTAS.md`.
</details>

<details><summary>Hint 3 — order independence</summary>

`kubectl apply -f dir/` applies in filename order, so a Deployment can be applied
before the ConfigMap it references. That is fine — the pod will fail to start,
then recover once the ConfigMap exists. If your manifests need a specific order,
that is a design problem, and module 10's sync waves are the real answer.
</details>

## Note

Do not delete the cluster at the end — labs 02, 03 and 04 build on this state.
