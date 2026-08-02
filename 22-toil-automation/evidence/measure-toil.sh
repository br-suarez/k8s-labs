#!/usr/bin/env bash
# Measure the toil, so the README quotes numbers instead of adjectives.
#
# Three runs of each path, on the same cluster, in the same state:
#   manual    — triage/manual-runbook.sh, the literal command sequence a human
#               types from the module 20 runbook
#   automated — triage/triage.sh executed inside the triage-runner pod
#
# The mechanical execution time is only part of the story and the smaller part;
# what this measures honestly is the machine-comparable portion. The human
# overhead (waking up, finding the runbook, copy-pasting, interpreting raw JSON)
# is reported separately in the README and clearly labelled as an estimate.
set -uo pipefail

cd "$(dirname "$0")/.."
OUT=./evidence
RUNS=${RUNS:-3}
SERVICE=slo-demo
NAMESPACE=slo-demo

PF_PID=""
cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus 9099:9090 >/dev/null 2>&1 &
PF_PID=$!
for _ in $(seq 1 40); do
  curl -sf http://localhost:9099/-/ready >/dev/null 2>&1 && break
  sleep 0.25
done

POD=$(kubectl get pod -n monitoring -l app=triage-runner -o jsonpath='{.items[0].metadata.name}')

# Count the commands a human actually types in the manual path.
CMD_COUNT=$(grep -cE '^\s*(curl|kubectl)' triage/manual-runbook.sh)

{
echo "======================================================================"
echo " TOIL MEASUREMENT — automated triage vs manual runbook"
echo " date:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo " runs:    ${RUNS} each"
echo " service: ${SERVICE} (ns ${NAMESPACE})"
echo "======================================================================"
echo
echo "Commands a human types in the manual path: ${CMD_COUNT}"
echo "Commands a human types in the automated path: 0 (fires on the alert)"
echo

echo "---- MANUAL RUNBOOK ----"
MANUAL_TOTAL=0
for i in $(seq 1 "$RUNS"); do
  START=$(date +%s.%N)
  PROM_URL=http://localhost:9099 ./triage/manual-runbook.sh "$SERVICE" "$NAMESPACE" >/dev/null 2>&1
  END=$(date +%s.%N)
  D=$(awk -v s="$START" -v e="$END" 'BEGIN{printf "%.2f", e-s}')
  MANUAL_TOTAL=$(awk -v t="$MANUAL_TOTAL" -v d="$D" 'BEGIN{printf "%.2f", t+d}')
  printf '  run %d: %ss\n' "$i" "$D"
done
MANUAL_AVG=$(awk -v t="$MANUAL_TOTAL" -v n="$RUNS" 'BEGIN{printf "%.2f", t/n}')
printf '  average: %ss\n\n' "$MANUAL_AVG"

echo "---- AUTOMATED TRIAGE ----"
AUTO_TOTAL=0
for i in $(seq 1 "$RUNS"); do
  START=$(date +%s.%N)
  kubectl exec -n monitoring "$POD" -- /app/triage.sh "$SERVICE" "$NAMESPACE" >/dev/null 2>&1
  END=$(date +%s.%N)
  D=$(awk -v s="$START" -v e="$END" 'BEGIN{printf "%.2f", e-s}')
  AUTO_TOTAL=$(awk -v t="$AUTO_TOTAL" -v d="$D" 'BEGIN{printf "%.2f", t+d}')
  printf '  run %d: %ss\n' "$i" "$D"
done
AUTO_AVG=$(awk -v t="$AUTO_TOTAL" -v n="$RUNS" 'BEGIN{printf "%.2f", t/n}')
printf '  average: %ss\n\n' "$AUTO_AVG"

echo "---- RESULT ----"
printf '  manual average:    %ss over %s separate commands\n' "$MANUAL_AVG" "$CMD_COUNT"
printf '  automated average: %ss, single invocation, zero human commands\n' "$AUTO_AVG"
awk -v m="$MANUAL_AVG" -v a="$AUTO_AVG" 'BEGIN{
  printf "  mechanical speedup: %.2fx\n", m/a
}'
echo
echo "  NOTE: the mechanical time is the SMALL part of the saving. The manual"
echo "  path also requires a human to be awake, find the runbook, paste each"
echo "  command, and read raw JSON. The automated path has already written the"
echo "  report by the time the page is acknowledged."
} | tee "$OUT/01-toil-measurement.txt"
