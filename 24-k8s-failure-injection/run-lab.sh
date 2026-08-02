#!/usr/bin/env bash
# Break three things, diagnose each one, fix each one, prove it.
#
# Every command in the DIAGNOSE sections is echoed before it runs, so the
# evidence file reads like a terminal session rather than a summary of one.
set -uo pipefail

cd "$(dirname "$0")"
NS=k8s-refresher
OUT=./evidence
mkdir -p "$OUT"

# run <description> <command...> — echo the command, then run it.
run() {
  printf '\n$ %s\n' "$*"
  "$@" 2>&1
}
hdr() { printf '\n========== %s ==========\n' "$*"; }

# ---------------------------------------------------------------- setup
# Delete and recreate: `spec.storageClassName` is immutable, so re-applying the
# broken PVC over a previously fixed one is rejected and the run is not
# reproducible. A clean namespace makes every run start from the same state.
kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1
kubectl create namespace "$NS" >/dev/null
kubectl apply -f broken/ >/dev/null
echo "Faults injected into namespace ${NS}. Waiting 75s for symptoms to develop..."
sleep 75

{
echo "======================================================================"
echo " KUBERNETES FAILURE INJECTION — diagnosis session"
echo " namespace: ${NS}"
echo " date:      $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

run kubectl get pods -n "$NS" -o wide
run kubectl get pvc -n "$NS"
run kubectl get svc -n "$NS"

# ================================================================ FAULT 1
hdr "FAULT 1 — web-crashloop is in CrashLoopBackOff"

echo "
First instinct is 'kubectl logs'. Whether that works is a race:
  - pod sitting in BackOff (no container running) -> returns the dead
    container's logs, which is what you want
  - pod mid-restart (new container starting)      -> returns the NEW container,
    which has not failed yet and may be empty
Backoff grows to 40s+, so it usually wins the race — and that is exactly what
makes it untrustworthy: it works right up until the one time it does not."
run kubectl logs -n "$NS" deploy/web-crashloop --tail=20

echo "
--previous always reads the container that already died, regardless of timing.
That determinism is the reason to reach for it first:"
POD1=$(kubectl get pod -n "$NS" -l app=web-crashloop -o jsonpath='{.items[0].metadata.name}')
run kubectl logs -n "$NS" "$POD1" --previous --tail=20

echo "
Confirm HOW it exited — exit code 1 is the application refusing to start,
which rules out OOMKilled (137) and a failing liveness probe:"
run kubectl get pod -n "$NS" "$POD1" -o jsonpath='{.status.containerStatuses[0].lastState.terminatedState}{.status.containerStatuses[0].lastState.terminated.reason}{"  exitCode="}{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
run kubectl describe pod -n "$NS" "$POD1"

# ================================================================ FAULT 2
hdr "FAULT 2a — Service web-nosel has no endpoints"

echo "
The Service exists and looks completely normal:"
run kubectl get svc -n "$NS" web-nosel

echo "
Endpoints is where the truth is. An empty list means the selector matched
nothing — the Service is a label query, and this query returns zero rows:"
run kubectl get endpoints -n "$NS" web-nosel
run kubectl describe svc -n "$NS" web-nosel

echo "
Compare what the Service asks for against what the pods actually have:"
run kubectl get svc -n "$NS" web-nosel -o jsonpath='{"service selector: "}{.spec.selector}{"\n"}'
run kubectl get pods -n "$NS" -l app=web-backend --show-labels

hdr "FAULT 2b — Service web-badport HAS endpoints and still fails"

echo "
This is the dangerous one: endpoints are populated, pods are Ready, every
health check passes."
run kubectl get endpoints -n "$NS" web-badport

echo "
But a request times out, because traffic goes to a port nothing listens on:"
run kubectl run curl-probe-badport -n "$NS" --rm -i --restart=Never --quiet \
  --image=curlimages/curl:8.10.1 --timeout=60s -- \
  curl -s -m 5 -o /dev/null -w 'http_code=%{http_code} exit=%{exitcode}\n' http://web-badport/

echo "
The mismatch: Service targetPort vs the port the container actually opens."
run kubectl get svc -n "$NS" web-badport -o jsonpath='{"targetPort: "}{.spec.ports[0].targetPort}{"\n"}'
run kubectl get deploy -n "$NS" web-backend -o jsonpath='{"containerPort: "}{.spec.template.spec.containers[0].ports[0].containerPort}{"  name: "}{.spec.template.spec.containers[0].ports[0].name}{"\n"}'

# ================================================================ FAULT 3
hdr "FAULT 3 — db-pending stuck Pending"

echo "
describe pod blames the scheduler, which sends people to check node capacity:"
POD3=$(kubectl get pod -n "$NS" -l app=db-pending -o jsonpath='{.items[0].metadata.name}')
run kubectl describe pod -n "$NS" "$POD3"

echo "
The nodes are fine. Follow the volume instead:"
run kubectl get pvc -n "$NS" data-fast
run kubectl describe pvc -n "$NS" data-fast

echo "
The requested StorageClass simply does not exist in this cluster:"
run kubectl get storageclass

} | tee "$OUT/01-diagnosis.txt"

# ---------------------------------------------------------------- fixes
{
echo "======================================================================"
echo " FIXES"
echo "======================================================================"

hdr "FIX 1 — correct the nginx directive, then roll the Deployment"
run kubectl apply -f fixed/01-crashloop-fixed.yaml
echo "
A ConfigMap change does not restart consumers, and a subPath mount does not
even refresh the file in the running container. The rollout is mandatory:"
run kubectl rollout restart deploy/web-crashloop -n "$NS"
run kubectl rollout status deploy/web-crashloop -n "$NS" --timeout=120s

hdr "FIX 2 — matching selector and named targetPort"
run kubectl apply -f fixed/02-service-fixed.yaml
sleep 5
run kubectl get endpoints -n "$NS" web-nosel web-badport

hdr "FIX 3 — recreate the PVC with an existing StorageClass"
echo "
storageClassName cannot be patched; the PVC must be replaced."
run kubectl delete pvc -n "$NS" data-fast --wait=true
run kubectl apply -f fixed/03-pvc-fixed.yaml
run kubectl rollout restart deploy/db-pending -n "$NS"
run kubectl rollout status deploy/db-pending -n "$NS" --timeout=120s

} | tee "$OUT/02-fixes.txt"

# ---------------------------------------------------------------- verify
sleep 10
{
echo "======================================================================"
echo " VERIFICATION"
echo "======================================================================"
run kubectl get pods -n "$NS" -o wide
run kubectl get pvc -n "$NS"
run kubectl get endpoints -n "$NS"

echo "
End-to-end check through both previously broken Services:"
run kubectl run curl-verify -n "$NS" --rm -i --restart=Never --quiet \
  --image=curlimages/curl:8.10.1 --timeout=90s -- sh -c \
  'for s in web-nosel web-badport; do printf "%-14s " "$s"; curl -s -m 5 -o /dev/null -w "http_code=%{http_code}\n" http://$s/ || echo FAILED; done'
} | tee "$OUT/03-verification.txt"

echo
echo "Evidence written to ${OUT}/"
