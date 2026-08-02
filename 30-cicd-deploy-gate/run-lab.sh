#!/usr/bin/env bash
# Run the gate for real, three times, against the live cluster:
#
#   A. a good release        -> gate passes  -> promotion happens
#   B. a release that is BROKEN BUT READY -> gate blocks -> production untouched
#   C. a release that cannot start        -> gate blocks at the rollout check
#
# Case B is the one worth building a gate for. The pods are Ready, the smoke
# test returns 200, and one request in five fails.
set -uo pipefail

# --- preflight -------------------------------------------------------------
# Fail before touching anything if there is no reachable cluster.
#
# Without this, the script runs to completion against a dead API server: every
# kubectl call returns "connection refused", and those errors get written into
# evidence/, OVERWRITING the captured run with garbage. That is not
# hypothetical — it happened once, and the committed evidence had to be
# restored from git.
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: no reachable Kubernetes cluster (kubectl cluster-info failed)." >&2
  echo "       Create it first, from 20-slo-error-budgets/:" >&2
  echo "         kind create cluster --config cluster/kind-config.yaml" >&2
  echo "       Nothing was written." >&2
  exit 1
fi
# ---------------------------------------------------------------------------


cd "$(dirname "$0")"
OUT=./evidence
mkdir -p "$OUT"
STAGING=cicd-staging
PROD=cicd-production
PORT=9120

PF_PID=""
cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus "${PORT}:9090" >/dev/null 2>&1 &
PF_PID=$!
for _ in $(seq 1 40); do
  curl -sf "http://localhost:${PORT}/-/ready" >/dev/null 2>&1 && break
  sleep 0.25
done
export PROM_URL="http://localhost:${PORT}"

hdr() { printf '\n========== %s ==========\n' "$*"; }
run() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }

prod_image() {
  kubectl get deploy checkout -n "$PROD" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "(not deployed)"
}

# The pipeline, condensed: deploy to staging, run the gate, promote only if it
# exits 0. This is the entire safety property being demonstrated.
pipeline() {
  local tag="$1" label="$2"
  hdr "PIPELINE RUN — ${label} (${tag})"

  echo "--- stage: deploy to staging"
  kubectl set image deploy/checkout checkout="slo-demo:${tag}" -n "$STAGING" 2>&1

  echo
  echo "--- stage: gate"
  if ./scripts/health-gate.sh "$STAGING" checkout checkout; then
    echo
    echo "--- stage: promote to production"
    kubectl set image deploy/checkout checkout="slo-demo:${tag}" -n "$PROD" 2>&1
    kubectl rollout status deploy/checkout -n "$PROD" --timeout=120s 2>&1
    echo "PIPELINE RESULT: promoted ${tag} to production"
  else
    echo
    echo "--- stage: promote to production  [SKIPPED — gate blocked]"
    echo "PIPELINE RESULT: ${tag} was NOT promoted"
  fi
  echo
  echo "production is running: $(prod_image)"
}

# ------------------------------------------------------------------ setup
for ns in "$STAGING" "$PROD"; do
  kubectl delete namespace "$ns" --ignore-not-found --wait=true >/dev/null 2>&1
  kubectl create namespace "$ns" >/dev/null
  kubectl apply -f manifests/app.yaml -n "$ns" >/dev/null
done
echo "Waiting for both environments to settle..."
kubectl rollout status deploy/checkout -n "$STAGING" --timeout=120s >/dev/null
kubectl rollout status deploy/checkout -n "$PROD"    --timeout=120s >/dev/null
sleep 45

{
echo "======================================================================"
echo " CI/CD DEPLOY GATE"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"
echo
echo "Baseline — both environments on slo-demo:v1"
run kubectl get deploy checkout -n "$STAGING" -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
run kubectl get deploy checkout -n "$PROD"    -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# CASE A ------------------------------------------------------------------
pipeline v3-fixed "GOOD RELEASE"

# CASE B ------------------------------------------------------------------
echo
echo "######################################################################"
echo "# The important case: a release that is BROKEN BUT READY."
echo "# slo-demo:v2-bad returns 500 to 20% of requests. Its pods pass every"
echo "# readiness probe, so kubectl rollout status succeeds and the smoke"
echo "# test returns 200. Only the SLO check can see the problem."
echo "######################################################################"
pipeline v2-bad "BROKEN RELEASE"

echo
echo "--- proof the broken release really was running in staging"
run kubectl get pods -n "$STAGING" -l app=checkout -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IMAGE:.spec.containers[0].image'

# CASE C ------------------------------------------------------------------
pipeline v9-nonexistent "UNSTARTABLE RELEASE"

hdr "FINAL STATE"
echo "
Production should still be on v3-fixed: the good release was promoted, and
neither the broken nor the unstartable one ever reached it."
run kubectl get deploy checkout -n "$PROD" -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
run kubectl get pods -n "$PROD" -l app=checkout -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,IMAGE:.spec.containers[0].image'
} | tee "$OUT/01-gate-runs.txt"

echo
echo "Evidence written to ${OUT}/"
