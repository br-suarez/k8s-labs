# Lab 00.03 — First cluster, then destroy it

**CORE · 40 min**

## Context

The skill here is not creating a cluster. It is being able to throw it away
without hesitating, because that is what makes an environment reproducible
rather than precious.

## The problem

### Part 1 — create and inspect

```bash
kind create cluster --config platform/deploy/clusters/lite.yaml
```

While it runs, watch what it is actually doing in another terminal:

```bash
docker ps
docker logs -f pulse-lite-control-plane 2>&1 | head -50
```

Then answer in `NOTAS.md`:

1. How many containers did kind create, and what is each one?
2. Where did your kubeconfig go? What context name did it add?
3. `kubectl get nodes -o wide` — what container runtime is reported, and what
   Kubernetes version? Does the version match the one pinned in `SETUP.md`?
4. `kubectl get pods -A` — name every pod running and say in one line what each
   is for. This is the control plane; you should be able to account for all of it.

### Part 2 — the port mapping

The `lite` profile maps container port 80 to host port 8080. Prove it:

```bash
kubectl run tmp-nginx --image=nginx:alpine --port=80
kubectl expose pod tmp-nginx --port=80 --type=NodePort
```

Now try to reach it from your host. **It will not work on 8080 as-is.** Work out
why, and what the profile would need for it to work. Write the answer down — you
implement it properly in module 02.

### Part 3 — destroy and rebuild

```bash
kind delete cluster --name pulse-lite
```

Now rebuild it and get back to a working `kubectl get nodes` **timed**. Record
the time in `NOTAS.md`.

## Expected outcome

- All nodes `Ready`
- You can account for every control-plane pod
- Rebuild time recorded, under 3 minutes

## Verification

```bash
kubectl get nodes --no-headers | awk '$2 != "Ready" { exit 1 }' && echo "nodes ready"
./platform/scripts/verify.sh tooling
```

## Staged hints

<details><summary>Hint 1 — Part 2, why 8080 does not reach the pod</summary>

`extraPortMappings` maps a *node* port to a *host* port. A NodePort Service
allocates a port in the 30000–32767 range, not 80. The mapping in the profile
sends host 8080 to node 80 — and nothing is listening on node port 80 yet.
</details>

<details><summary>Hint 2 — Part 2, what would make it work</summary>

Two options, and the difference matters: add an `extraPortMapping` for the
specific NodePort, or run something that actually listens on node port 80 — which
is what an ingress controller or Gateway does. The second is why the profile
labels the node `ingress-ready=true`.
</details>

## Cleanup

```bash
kubectl delete pod tmp-nginx --ignore-not-found
kubectl delete service tmp-nginx --ignore-not-found
kind delete cluster --name pulse-lite
```

Leave no cluster running at the end of a session unless the next lab needs it.
