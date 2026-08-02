# Lab 04.04 — HPA on autoscaling/v2

**CORE · 40 min**

## Context

The reference lab repositories all ship HPA manifests using `autoscaling/v2beta2`,
removed in Kubernetes 1.26. You are going to apply one deliberately, read the
error, and understand what "removed API" means — because you will meet this on
every cluster upgrade for the rest of your career.

## The problem

### Part 1 — meet the failure

```bash
cat <<'EOF' | kubectl apply -f - -n pulse
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: pulse-api-old
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pulse-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
EOF
```

Read the error carefully. Then answer:

1. What is the difference between an API being *deprecated* and *removed*?
2. How do you find out, before upgrading a cluster, that you are using an API
   that the next version removes?
3. Where did the object go? Is it stored anywhere?

### Part 2 — do it properly

Install metrics-server, then write the `autoscaling/v2` equivalent. It is not a
string substitution — compare the `metrics` structure between versions.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

That patch is needed on kind because the kubelet serving certificates are not
signed by a CA metrics-server trusts. **Understand why you are doing it** — do
not carry that flag to a production cluster without knowing what it disables.

### Part 3 — make it scale

Generate load and watch it work:

```bash
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- http://pulse-api:8080/api/results >/dev/null 2>&1; done'

kubectl get hpa -n pulse -w
```

Record: time from load start to first scale-up, and from load stop to scale-down.
They are very different. Explain why in `NOTAS.md`.

### Part 4 — scale on the right signal

CPU is a poor autoscaling signal for `pulse-worker`, which is I/O-bound. The
right signal is `pulse_worker_queue_depth`.

Sketch the HPA that would use it — you cannot complete this until module 07
supplies the metrics pipeline. Write down what is missing and why. This is the
hand-off into the observability modules.

## Expected outcome

- The removed-API error, read and understood
- A working `autoscaling/v2` HPA that scales under load
- Scale-up and scale-down timings, with an explanation of the asymmetry
- A written sketch of queue-depth-based scaling

## Staged hints

<details><summary>Hint 1 — the asymmetry</summary>

Scale-up is fast by default; scale-down waits through a stabilisation window of
300s. The reasoning is that scaling down too eagerly causes thrashing, and the
cost of being briefly over-provisioned is much lower than the cost of flapping.
Tunable via `behavior.scaleDown.stabilizationWindowSeconds`.
</details>

<details><summary>Hint 2 — question 2</summary>

`kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis`, the
audit log, or tooling such as `pluto` and `kubent` scanning your manifests. On a
managed cluster the provider usually surfaces deprecation warnings before an
upgrade — reading them is the job.
</details>

## Cleanup

```bash
kubectl delete pod load -n pulse --ignore-not-found
```
