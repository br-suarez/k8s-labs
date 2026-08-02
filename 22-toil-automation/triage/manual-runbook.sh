#!/usr/bin/env bash
# The toil being replaced.
#
# This is the literal sequence an on-call engineer types when the availability
# page fires, taken step by step from 20-slo-error-budgets/README.md#runbook.
# Each command is a separate invocation with raw, unformatted output — exactly
# what a human sees.
#
# It exists to be TIMED against triage.sh, so the "time saved" claim in the
# README is a measurement rather than an assertion.
#
# Usage:  manual-runbook.sh <service> <namespace>
set -uo pipefail

SERVICE=${1:-slo-demo}
NAMESPACE=${2:-slo-demo}
PROM=${PROM_URL:-http://localhost:9099}

step() { printf '\n$ %s\n' "$*"; }

# --- step 1: is it real? -----------------------------------------------------
step "curl prometheus: request rate"
curl -sG --data-urlencode "query=sum(rate(http_requests_total{job=\"${SERVICE}\",path=\"/api\"}[1m]))" \
  "${PROM}/api/v1/query"
echo

step "curl prometheus: 5m error ratio"
curl -sG --data-urlencode "query=slo:availability_error:ratio_rate5m{service=\"${SERVICE}\"}" \
  "${PROM}/api/v1/query"
echo

step "curl prometheus: 1h error ratio"
curl -sG --data-urlencode "query=slo:availability_error:ratio_rate1h{service=\"${SERVICE}\"}" \
  "${PROM}/api/v1/query"
echo

# --- step 2: scope -----------------------------------------------------------
step "curl prometheus: per-pod error ratio"
curl -sG --data-urlencode "query=sum by (pod) (rate(http_requests_total{job=\"${SERVICE}\",path=\"/api\",status=~\"5..\"}[1m])) / sum by (pod) (rate(http_requests_total{job=\"${SERVICE}\",path=\"/api\"}[1m]))" \
  "${PROM}/api/v1/query"
echo

# --- step 3: budget ----------------------------------------------------------
step "curl prometheus: error budget remaining"
curl -sG --data-urlencode "query=slo:availability_error_budget_remaining:ratio6h{service=\"${SERVICE}\"}" \
  "${PROM}/api/v1/query"
echo

step "curl prometheus: burn rate"
curl -sG --data-urlencode "query=slo:availability_burn_rate:1h{service=\"${SERVICE}\"}" \
  "${PROM}/api/v1/query"
echo

# --- step 4: recent deploys --------------------------------------------------
step "kubectl get rs -n ${NAMESPACE}"
kubectl get rs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp

step "kubectl get rollout -n ${NAMESPACE}"
kubectl get rollout -n "$NAMESPACE" 2>/dev/null || echo "(no rollouts)"

# --- step 5: pod health ------------------------------------------------------
step "kubectl get pods -n ${NAMESPACE} -l app=${SERVICE} -o wide"
kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" -o wide

step "kubectl get events -n ${NAMESPACE} --field-selector type=Warning"
kubectl get events -n "$NAMESPACE" --field-selector type=Warning --sort-by=.lastTimestamp | tail -6

# --- step 6: logs ------------------------------------------------------------
step "kubectl logs (first pod)"
POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n "$NAMESPACE" "$POD" --tail=10 --since=5m
