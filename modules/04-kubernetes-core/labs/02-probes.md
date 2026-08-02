# Lab 04.02 — Probes, and the cascading restart

**CORE · 50 min**

## Context

You will configure probes correctly, then deliberately misconfigure one and watch
it take down a healthy service. Seeing the cascade happen is the point — reading
about it does not stick.

## The problem

### Part 1 — measure the readiness window

`pulse-api` returns 503 on `/readyz` for its first 2 seconds. Prove it:

```bash
kubectl run probe-test --image=<your pulse-api digest> --restart=Never -n pulse
for i in $(seq 10); do
  kubectl exec -n pulse probe-test -- \
    wget -qO- -S http://localhost:8080/readyz 2>&1 | grep HTTP
  sleep 0.5
done
```

### Part 2 — the wrong probe

Point the readiness probe at `/healthz`. Then run load through the Service while
you trigger a rollout:

```bash
kubectl run load --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- -T2 http://pulse-api:8080/api/checks >/dev/null 2>&1 \
    && echo ok || echo FAIL; sleep 0.05; done'

kubectl rollout restart deployment/pulse-api -n pulse
sleep 45
kubectl logs load -n pulse | sort | uniq -c
```

Record the failure percentage. This is the break-fix scenario, reproduced by you.

### Part 3 — fix it and re-measure

Point readiness at `/readyz`, add a `startupProbe`, add `preStop`, drop
`maxSurge` to 1. Re-run part 2. Record the new number.

**Both numbers go in the module README.** "I fixed the probes" is not a result;
"15% failures per deploy to 0%, measured across 900 requests" is.

### Part 4 — the cascade

Now make the liveness probe aggressive:

```yaml
livenessProbe:
  httpGet: { path: /healthz, port: 8080 }
  periodSeconds: 2
  timeoutSeconds: 1
  failureThreshold: 1
```

Then load the service hard enough that `/healthz` occasionally exceeds 1s:

```bash
kubectl run hammer --image=busybox -n pulse --restart=Never -- \
  sh -c 'while :; do wget -qO- http://pulse-api:8080/api/results >/dev/null 2>&1 & done'
```

Watch:

```bash
kubectl get pods -n pulse -w
```

Record what happens to `RESTARTS` over three minutes, and explain in `NOTAS.md`
why restarting pods makes the situation worse rather than better.

## Expected outcome

- Failure percentage before and after the fix
- A reproduced restart cascade, with the restart counts
- A written explanation of why liveness probes should be lenient

## Cleanup

```bash
kubectl delete pod load hammer probe-test -n pulse --ignore-not-found
```

## Staged hints

<details><summary>Hint 1 — the cascade mechanism</summary>

Killing a busy pod does not reduce load; it redistributes it. The remaining pods
get more traffic, respond more slowly, and their probes start failing too. The
mechanism designed to protect the service is what removes its capacity.
</details>

<details><summary>Hint 2 — telling the two failure modes apart</summary>

`kubectl describe pod` shows the probe failure reason. `Liveness probe failed:
HTTP probe failed with statuscode: 503` is a real application failure. `Liveness
probe failed: Get ... context deadline exceeded` is a **timeout** — the app was
slow, not broken. Those two lines call for completely opposite responses.
</details>
