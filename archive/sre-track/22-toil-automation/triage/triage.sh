#!/usr/bin/env bash
# Automated execution of the module 20 runbook.
#
# Every question a human answers in the first two minutes of an availability
# page, answered before they open the laptop:
#
#   1. Is this real, or a ratio computed over three requests?
#   2. Is one pod failing or all of them?
#   3. How much error budget is left — roll back, or fix forward?
#   4. Did something just ship?
#   5. Are pods restarting, and what do the logs say?
#
# Usage:  triage.sh <service> <namespace>
# Env:    PROM_URL (default: in-cluster Prometheus)
set -uo pipefail   # deliberately NOT -e: a failing probe must not abort the
                   # report. A partial triage during an incident beats none.

SERVICE=${1:-slo-demo}
NAMESPACE=${2:-slo-demo}
PROM_URL=${PROM_URL:-http://kube-prom-stack-kube-prome-prometheus.monitoring.svc.cluster.local:9090}

hr() { printf '%s\n' "------------------------------------------------------------------"; }
sec() { printf '\n== %s\n' "$*"; }

# promq <query> -> single scalar, or "no data"
promq() {
  curl -sG --max-time 10 --data-urlencode "query=$1" "${PROM_URL}/api/v1/query" \
    | jq -r '.data.result[0].value[1] // "no data"'
}

# promq_table <query> <label> -> "labelvalue  value" per series
promq_table() {
  curl -sG --max-time 10 --data-urlencode "query=$1" "${PROM_URL}/api/v1/query" \
    | jq -r --arg l "$2" '.data.result[] | "    \(.metric[$l] // "?")  \(.value[1])"'
}

pct() { awk -v x="$1" 'BEGIN{ if (x=="no data") print "no data"; else printf "%.3f%%", x*100 }'; }

echo "=================================================================="
echo " AUTOMATED TRIAGE — ${SERVICE} (ns ${NAMESPACE})"
echo " generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo " runbook:   20-slo-error-budgets/README.md#runbook"
echo "=================================================================="

# ---------------------------------------------------------------- step 1
sec "1. IS IT REAL? (traffic volume — a ratio over no traffic is noise)"
RATE=$(promq "sum(rate(http_requests_total{job=\"${SERVICE}\",path=\"/api\"}[1m]))")
printf '    request rate: %s req/s\n' "$RATE"
if [[ "$RATE" != "no data" ]] && awk -v r="$RATE" 'BEGIN{exit !(r < 1)}'; then
  echo "    ⚠ VERY LOW TRAFFIC — the error ratio below is statistically weak."
fi

E5M=$(promq "slo:availability_error:ratio_rate5m{service=\"${SERVICE}\"}")
E1H=$(promq "slo:availability_error:ratio_rate1h{service=\"${SERVICE}\"}")
printf '    error ratio 5m: %s\n' "$(pct "$E5M")"
printf '    error ratio 1h: %s\n' "$(pct "$E1H")"
echo "    (SLO error budget is 0.5%; fast-burn page threshold is 7.2%)"

# ---------------------------------------------------------------- step 2
sec "2. SCOPE — one pod or all of them?"
echo "  error ratio per pod (1m):"
promq_table "sum by (pod) (rate(http_requests_total{job=\"${SERVICE}\",path=\"/api\",status=~\"5..\"}[1m]))
             / sum by (pod) (rate(http_requests_total{job=\"${SERVICE}\",path=\"/api\"}[1m]))" pod
echo
echo "  → all pods similar  = systemic (bad deploy, dependency, config)"
echo "  → one pod an outlier = that pod (kubectl delete pod, then investigate)"

# ---------------------------------------------------------------- step 3
sec "3. ERROR BUDGET — roll back, or fix forward?"
BUDGET=$(promq "slo:availability_error_budget_remaining:ratio6h{service=\"${SERVICE}\"}")
BURN=$(promq "slo:availability_burn_rate:1h{service=\"${SERVICE}\"}")
printf '    budget remaining (6h proxy): %s\n' "$BUDGET"
printf '    burn rate (1h):              %sx\n' "$(awk -v x="$BURN" 'BEGIN{ if (x=="no data") print "no data"; else printf "%.2f", x }')"
if [[ "$BUDGET" != "no data" ]] && awk -v b="$BUDGET" 'BEGIN{exit !(b < 0.25)}'; then
  echo "    ⚠ BUDGET BELOW 25% — policy says stop shipping and roll back."
fi

# ---------------------------------------------------------------- step 4
sec "4. DID SOMETHING JUST SHIP?"
echo "  ReplicaSets by age (newest first):"
kubectl get rs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,AGE:.metadata.creationTimestamp' \
  2>/dev/null | tail -6 | sed 's/^/    /'
echo
echo "  Argo Rollouts revisions (if managed by a Rollout):"
kubectl get rollout -n "$NAMESPACE" \
  -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,IMAGE:.spec.template.spec.containers[0].image' \
  2>/dev/null | sed 's/^/    /' || echo "    (none)"

# ---------------------------------------------------------------- step 5
sec "5. POD HEALTH & RESTARTS"
kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image' \
  2>/dev/null | sed 's/^/    /'

sec "6. RECENT WARNING EVENTS"
kubectl get events -n "$NAMESPACE" --field-selector type=Warning \
  --sort-by=.lastTimestamp 2>/dev/null | tail -6 | sed 's/^/    /' \
  || echo "    (none)"

sec "7. RECENT LOGS FROM ONE POD"
POD=$(kubectl get pods -n "$NAMESPACE" -l app="$SERVICE" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$POD" ]]; then
  echo "    pod: $POD"
  kubectl logs -n "$NAMESPACE" "$POD" --tail=10 --since=5m 2>/dev/null | sed 's/^/    /' \
    || echo "    (no logs)"
else
  echo "    (no pods found for app=${SERVICE})"
fi

hr
echo " END OF TRIAGE"
hr
