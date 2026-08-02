#!/usr/bin/env bash
# End-to-end proof: break the service, let the SLO alert fire, and show the
# triage report being produced with nobody watching.
#
# The number this run exists to produce is t_fire -> t_report: how long after
# the page fires the diagnosis is already sitting there. In the manual path that
# interval is however long it takes a human to wake up and start typing.
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


cd "$(dirname "$0")/.."
OUT=./evidence
SLO_MODULE=../20-slo-error-budgets
NS=slo-demo
APP_URL=${APP_URL:-http://localhost:30080}
ERROR_RATE=${ERROR_RATE:-1.0}

PF_PID=""
cleanup() {
  [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true
  echo "==> healing service"
  for _ in $(seq 1 30); do
    curl -s -X POST "${APP_URL}/chaos?error_rate=0.001&slow_rate=0.005" -o /dev/null
  done
}
trap cleanup EXIT

kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus 9100:9090 >/dev/null 2>&1 &
PF_PID=$!
for _ in $(seq 1 40); do
  curl -sf http://localhost:9100/-/ready >/dev/null 2>&1 && break
  sleep 0.25
done

POD=$(kubectl get pod -n monitoring -l app=triage-runner -o jsonpath='{.items[0].metadata.name}')
ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
epoch() { date -u +%s; }

alert_state() {
  curl -s "http://localhost:9100/api/v1/rules?type=alert" \
    | jq -r '[.data.groups[].rules[] | select(.name=="SLODemoAvailabilityFastBurn")][0].state // "unknown"'
}

report_count() {
  kubectl exec -n monitoring "$POD" -- sh -c 'ls -1 /reports 2>/dev/null | wc -l' 2>/dev/null | tr -d '[:space:]'
}

{
echo "======================================================================"
echo " END TO END — alert fires, triage runs unattended"
echo " started: $(ts)"
echo "======================================================================"
echo

BEFORE=$(report_count)
echo "reports on disk before: ${BEFORE}"
echo "alert state before:     $(alert_state)"
echo

echo "==> injecting error_rate=${ERROR_RATE} at $(ts)"
for _ in $(seq 1 30); do
  curl -s -X POST "${APP_URL}/chaos?error_rate=${ERROR_RATE}" -o /dev/null
done
T_INJECT=$(epoch)
curl -s "${APP_URL}/chaos"; echo
echo

echo "==> waiting for SLODemoAvailabilityFastBurn to reach FIRING"
T_FIRE=""
for i in $(seq 1 60); do
  S=$(alert_state)
  printf '  [%s] poll %-2s state=%s\n' "$(ts)" "$i" "$S"
  if [[ "$S" == "firing" ]]; then
    T_FIRE=$(epoch)
    echo "  ALERT FIRING at $(ts)"
    break
  fi
  sleep 20
done

if [[ -z "$T_FIRE" ]]; then
  echo "ERROR: alert never fired within the polling budget"
  exit 1
fi

echo
echo "==> waiting for a new triage report to appear (nobody is doing anything)"
T_REPORT=""
for i in $(seq 1 30); do
  NOW=$(report_count)
  printf '  [%s] poll %-2s reports=%s\n' "$(ts)" "$i" "$NOW"
  if [[ -n "$NOW" && -n "$BEFORE" && "$NOW" -gt "$BEFORE" ]]; then
    T_REPORT=$(epoch)
    echo "  REPORT WRITTEN at $(ts)"
    break
  fi
  sleep 10
done

echo
echo "---- TIMELINE ----"
printf '  chaos injected  -> alert firing : %ss\n' "$((T_FIRE - T_INJECT))"
if [[ -n "$T_REPORT" ]]; then
  printf '  alert firing    -> report ready : %ss   <-- unattended\n' "$((T_REPORT - T_FIRE))"
  printf '  chaos injected  -> report ready : %ss\n' "$((T_REPORT - T_INJECT))"
else
  echo "  no report appeared"
fi
} | tee "$OUT/02-e2e-timeline.txt"

echo
echo "==> receiver log"
kubectl logs -n monitoring "$POD" --tail=40 | tee "$OUT/03-receiver-log.txt"

echo
echo "==> newest triage report"
LATEST=$(kubectl exec -n monitoring "$POD" -- sh -c 'ls -1t /reports 2>/dev/null | head -1' | tr -d '\r')
if [[ -n "$LATEST" ]]; then
  kubectl exec -n monitoring "$POD" -- cat "/reports/${LATEST}" | tee "$OUT/04-triage-report.txt"
else
  echo "(no report found)"
fi
