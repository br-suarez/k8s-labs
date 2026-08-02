# Refresher 24: Kubernetes Failure Injection

**Module:** 24 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

Three faults injected into a live kind cluster, diagnosed from symptoms, fixed
and verified. Full terminal session in
[`evidence/01-diagnosis.txt`](./evidence/01-diagnosis.txt),
[`02-fixes.txt`](./evidence/02-fixes.txt),
[`03-verification.txt`](./evidence/03-verification.txt).

```bash
./run-lab.sh    # breaks, diagnoses, fixes and verifies — reproducible from scratch
```

---

## Fault 1 — CrashLoopBackOff

**What broke.** A ConfigMap-mounted `nginx.conf` with `worker_procesess` instead
of `worker_processes`. nginx refuses to start on an unknown directive rather
than ignoring it, exits 1, and Kubernetes restarts it on a growing backoff.

**How it was diagnosed.** Pod status says `CrashLoopBackOff`, which tells you
*that* it is failing and nothing about *why*. The application's own output is
the only thing that does:

```
2026/08/02 05:38:47 [emerg] 1#1: unknown directive "worker_procesess" in /etc/nginx/nginx.conf:3
nginx: [emerg] unknown directive "worker_procesess" in /etc/nginx/nginx.conf:3
```

File and line number, straight from the process. Then confirm *how* it died,
because the exit code narrows the class of problem before reading anything else:

```
Error  exitCode=1
```

Exit 1 is the application refusing to start. It rules out `137`/`OOMKilled`
(memory limit), `143` (SIGTERM, usually a failing liveness probe), and
`CreateContainerConfigError` (a missing ConfigMap/Secret key, which never
reaches the application at all).

**The key command.**

```bash
kubectl logs <pod> --previous
```

Worth being precise about *why*, because the usual advice is oversimplified —
and this run disproved it. Plain `kubectl logs` **did** return the error here.
Whether it does is a race:

- pod sitting in `BackOff`, no container running → returns the dead container's
  logs, which is what you want
- pod mid-restart, new container starting → returns the **new** container, which
  has not failed yet and may be empty

Backoff grows to 40s+, so plain `logs` usually wins that race. That is exactly
what makes it untrustworthy: it works right up until the one time it does not.
`--previous` reads the container that already died regardless of timing.

**The fix.** Correct the directive — *and roll the Deployment*:

```bash
kubectl apply -f fixed/01-crashloop-fixed.yaml
kubectl rollout restart deploy/web-crashloop -n k8s-refresher
```

Editing the ConfigMap alone changes nothing. Consumers are not restarted on a
ConfigMap change, and with a `subPath` mount the file inside a running container
is never refreshed at all — `subPath` copies the file at mount time instead of
symlinking it.

---

## Fault 2a — Service with no endpoints

**What broke.** Service selector `app: web-frontend`; the pods are labelled
`app: web-backend`.

**How it was diagnosed.** `kubectl get svc` looks perfectly healthy — a
ClusterIP, a port, no error anywhere. A Service is just a stored label query,
and `get svc` shows the query, not its result. The result lives in Endpoints:

```
$ kubectl get endpoints -n k8s-refresher web-nosel
NAME        ENDPOINTS   AGE
web-nosel   <none>      79s
```

`<none>` means the selector matched zero pods. Then compare the two label sets
directly:

```bash
kubectl get svc web-nosel -o jsonpath='{.spec.selector}'   # app:web-frontend
kubectl get pods -l app=web-backend --show-labels          # app=web-backend
```

**The key command.**

```bash
kubectl get endpoints <svc>      # or: kubectl describe svc <svc>
```

Note: Kubernetes 1.33+ prints `Warning: v1 Endpoints is deprecated in v1.33+;
use discovery.k8s.io/v1 EndpointSlice`. The muscle-memory command still works,
but the forward-compatible one is `kubectl get endpointslices -l
kubernetes.io/service-name=<svc>`.

---

## Fault 2b — Service *with* endpoints that still fails

**What broke.** Selector correct, `targetPort: 8080`, nginx listening on `80`.

**How it was diagnosed.** This is the dangerous variant, because every check
that catches 2a passes here:

```
$ kubectl get endpoints -n k8s-refresher web-badport
NAME          ENDPOINTS                       AGE
web-badport   10.244.1.23:80,10.244.2.64:80   80s
```

Endpoints populated, pods `Ready`, no restarts, no events. The only way to see
it is to actually send a request:

```
http_code=000 exit=7
```

curl exit `7` is "failed to connect" — the connection never opened, as opposed
to a `502` (connected, upstream broke) or a timeout. Then compare the two
numbers that have to agree:

```bash
kubectl get svc web-badport -o jsonpath='{.spec.ports[0].targetPort}'          # 8080
kubectl get deploy web-backend -o jsonpath='{...containers[0].ports[0].containerPort}'  # 80
```

**The key command.** There is no status field for this one — the diagnosis is an
end-to-end request:

```bash
kubectl run probe --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s -m 5 -o /dev/null -w 'http_code=%{http_code} exit=%{exitcode}\n' http://web-badport/
```

**The fix.** Reference the container port **by name**, not by number:

```yaml
ports:
  - port: 80
    targetPort: http     # name defined once in the pod spec
```

The name is declared in one place, so the Service cannot silently drift out of
sync with it. That is the class of bug 2b is, eliminated structurally.

---

## Fault 3 — Pod Pending on an unbound PVC

**What broke.** PVC requesting `storageClassName: fast-ssd`. kind ships exactly
one StorageClass, `standard`.

**How it was diagnosed.** `describe pod` actively points the wrong way:

```
0/3 nodes are available: pod has unbound immediate PersistentVolumeClaims.
```

That reads like a scheduling problem, and sends people to check node capacity,
taints and affinity. The scheduler is fine — it is correctly refusing to place a
pod whose volume does not exist. The real explanation is one object further down:

```
$ kubectl describe pvc data-fast
Warning  ProvisioningFailed  8s (x6 over 83s)  persistentvolume-controller
         storageclass.storage.k8s.io "fast-ssd" not found
```

Confirmed against reality:

```
$ kubectl get storageclass
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer
```

**The key command.**

```bash
kubectl describe pvc <pvc>
```

**The fix.** `storageClassName` cannot be patched, so the PVC has to be deleted
and recreated:

```bash
kubectl delete pvc data-fast -n k8s-refresher
kubectl apply -f fixed/03-pvc-fixed.yaml
kubectl rollout restart deploy/db-pending -n k8s-refresher
```

Trivial here because the volume was empty. On a bound PVC holding real data this
is a migration — provision a new volume, copy, cut over — not an edit.

---

## Verification

```
$ kubectl get pvc -n k8s-refresher
NAME        STATUS   VOLUME                                     CAPACITY   STORAGECLASS
data-fast   Bound    pvc-5a32a16c-ac8b-46de-a528-f6f6c0a3d0f2   1Gi        standard

$ kubectl get endpoints -n k8s-refresher
web-badport   10.244.1.23:80,10.244.2.64:80
web-nosel     10.244.1.23:80,10.244.2.64:80

web-nosel      http_code=200
web-badport    http_code=200
```

All pods `Running`, both Services returning 200.

---

## What I re-learned

- **Symptom and cause live in different objects, and Kubernetes will point at
  the wrong one.** The Pending pod's own event blames the scheduler. The Service
  with no endpoints looks healthy in `get svc`. In both cases the object showing
  the symptom is not the object holding the explanation — the habit worth having
  is following the dependency (pod → PVC → StorageClass, Service → Endpoints →
  pod labels) rather than reading the first message harder.

- **"Endpoints exist" is not "the Service works".** 2a and 2b are indistinguishable
  to a client and have nothing in common diagnostically. Every status-based check
  passes on 2b; only an actual request finds it. Referencing `targetPort` by name
  removes the failure mode entirely, which beats being good at diagnosing it.

- **The exit code narrows the search before any logs are read.** `1` = the app
  refused to start, `137` = OOMKilled, `143` = SIGTERM (usually a liveness probe),
  `CreateContainerConfigError` = a missing ConfigMap/Secret key that never
  reached the app. Checking `lastState.terminated` first turns "read everything"
  into "read one thing".

- **I had internalised a rule about `kubectl logs --previous` that is not quite
  true, and this run showed it.** Plain `logs` returned the error fine, because
  the pod was sitting in backoff with no live container. `--previous` is the
  right default not because plain `logs` is *wrong*, but because it is
  *timing-dependent* — and a diagnostic that usually works is worse than one that
  always does.
