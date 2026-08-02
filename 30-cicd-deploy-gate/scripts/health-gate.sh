#!/usr/bin/env bash
# THE GATE.
#
# Decides whether a release that is already running in staging may be promoted
# to production. Exits 0 to promote, non-zero to block.
#
# Three checks, in increasing order of what they can detect:
#
#   1. Rollout completed      — did the pods start at all?
#   2. Smoke test             — does the service answer?
#   3. SLO verification       — are users actually being served correctly?
#
# Check 3 is the one that matters and the one most pipelines skip. A release can
# pass 1 and 2 while failing one request in five: readiness probes answer "is
# the process up", not "is it working". That is the whole reason this gate
# queries Prometheus instead of trusting kubectl.
#
# Usage: health-gate.sh <namespace> <deployment> <service>
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


NS=${1:-cicd-staging}
DEPLOY=${2:-checkout}
SVC=${3:-checkout}

PROM_URL=${PROM_URL:-http://localhost:9120}
ROLLOUT_TIMEOUT=${ROLLOUT_TIMEOUT:-90s}
# Must exceed the rate window below, or the query reads traffic from before the
# new version was deployed and grades the OLD release.
SOAK_SECONDS=${SOAK_SECONDS:-90}
ERROR_BUDGET=${ERROR_BUDGET:-0.005}   # 0.5%, from module 20's SLO
LATENCY_SLO_MS=${LATENCY_SLO_MS:-300}

fail() { printf '\n\033[1;31m[GATE] BLOCKED: %s\033[0m\n' "$*"; exit 1; }
pass() { printf '\033[1;32m[GATE] %s\033[0m\n' "$*"; }
info() { printf '[GATE] %s\n' "$*"; }

promq() {
  curl -sG --max-time 10 --data-urlencode "query=$1" "${PROM_URL}/api/v1/query" \
    | jq -r '.data.result[0].value[1] // "nodata"'
}

echo "=================================================================="
echo " DEPLOY GATE — ${DEPLOY} in ${NS}"
echo " $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "=================================================================="

# ---------------------------------------------------------------- check 1
info "1/3 waiting for rollout to complete (timeout ${ROLLOUT_TIMEOUT})"
if ! kubectl rollout status "deploy/${DEPLOY}" -n "$NS" --timeout="$ROLLOUT_TIMEOUT"; then
  kubectl get pods -n "$NS" -l "app=${DEPLOY}" \
    -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,REASON:.status.containerStatuses[0].state.waiting.reason'
  fail "rollout did not complete — pods never became Ready"
fi
pass "rollout completed"

# ---------------------------------------------------------------- check 2
#
# Retried, deliberately. The first version of this gate ran the smoke test once
# and BLOCKED A HEALTHY RELEASE with http_code=000 — a connection failure in the
# seconds between `rollout status` returning and Service endpoints catching up.
#
# A gate that produces false negatives is worse than no gate at all: the team
# learns that red means "run it again", and then ignores it the day it is right.
# Retrying makes the check answer "is this persistently broken" instead of "was
# this instant unlucky", which is the question actually being asked.
info "2/3 smoke test (up to ${SMOKE_RETRIES:=6} attempts)"
SMOKE=""
for attempt in $(seq 1 "$SMOKE_RETRIES"); do
  SMOKE=$(kubectl run "smoke-$RANDOM" -n "$NS" --rm -i --restart=Never --quiet \
    --image=curlimages/curl:8.10.1 --timeout=60s -- \
    sh -c "curl -s -m 5 -o /dev/null -w '%{http_code}' http://${SVC}:8080/healthz" 2>/dev/null \
    | tr -dc '0-9' | tail -c 3)
  [[ "$SMOKE" == "200" ]] && break
  info "     attempt ${attempt}/${SMOKE_RETRIES} returned '${SMOKE}', retrying in 5s"
  sleep 5
done

if [[ "$SMOKE" != "200" ]]; then
  fail "smoke test returned '${SMOKE}' instead of 200 after ${SMOKE_RETRIES} attempts"
fi
pass "smoke test returned 200"

# ---------------------------------------------------------------- check 3
info "3/3 soaking ${SOAK_SECONDS}s, then verifying against the SLO"
info "     (the soak must outlast the rate window, or the query grades the"
info "      PREVIOUS release using traffic recorded before this deploy)"
sleep "$SOAK_SECONDS"

ERR=$(promq "sum(rate(http_requests_total{namespace=\"${NS}\",path=\"/api\",status=~\"5..\"}[1m])) / sum(rate(http_requests_total{namespace=\"${NS}\",path=\"/api\"}[1m]))")
REQ=$(promq "sum(rate(http_requests_total{namespace=\"${NS}\",path=\"/api\"}[1m]))")
P99=$(promq "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"${NS}\",path=\"/api\"}[1m])))")

printf '       request rate : %s req/s\n' "$REQ"
printf '       error ratio  : %s (budget %s)\n' "$ERR" "$ERROR_BUDGET"
printf '       p99 latency  : %s s (slo %sms)\n' "$P99" "$LATENCY_SLO_MS"

# No data is not a pass. A release that receives no traffic has not been
# verified, and treating "nothing to measure" as "nothing wrong" is how a gate
# becomes decorative.
[[ "$ERR" == "nodata" || "$REQ" == "nodata" ]] && fail "no metrics for this release — cannot verify, so cannot promote"
awk -v r="$REQ" 'BEGIN{exit !(r < 1)}' && fail "traffic too low (${REQ} req/s) to verify anything"

awk -v e="$ERR" -v b="$ERROR_BUDGET" 'BEGIN{exit !(e > b)}' \
  && fail "error ratio ${ERR} exceeds the ${ERROR_BUDGET} error budget"

if [[ "$P99" != "nodata" ]]; then
  awk -v p="$P99" -v s="$LATENCY_SLO_MS" 'BEGIN{exit !(p*1000 > s)}' \
    && fail "p99 ${P99}s exceeds the ${LATENCY_SLO_MS}ms objective"
fi

pass "SLO verification passed"
echo
pass "PROMOTE APPROVED"
