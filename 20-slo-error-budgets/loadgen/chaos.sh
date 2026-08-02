#!/usr/bin/env bash
# Drive slo-demo failure injection and read SLO state back out of Prometheus.
#
#   ./chaos.sh status              current chaos settings + live SLI + burn rate
#   ./chaos.sh break [rate]        inject 5xx errors   (default 0.25 = 25%)
#   ./chaos.sh slow  [rate]        inject slow requests (default 0.40 = 40%)
#   ./chaos.sh heal                return to steady state
#   ./chaos.sh alerts              SLO alerts currently pending or firing
#   ./chaos.sh watch               poll status every 30s until interrupted
#
# Prometheus is reached through a short-lived `kubectl port-forward` rather than
# by spawning a curl pod per query: a pod spawn costs ~10s and its attach
# warnings corrupt stdout, which made the captured evidence unreadable.
set -euo pipefail

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


NS=slo-demo
APP_URL=${APP_URL:-http://localhost:30080}
PROM_SVC=svc/kube-prom-stack-kube-prome-prometheus
PROM_NS=monitoring
PROM_PORT=${PROM_PORT:-9091}

PF_PID=""
cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

prom_forward() {
  [[ -n "$PF_PID" ]] && return 0
  kubectl port-forward -n "$PROM_NS" "$PROM_SVC" "${PROM_PORT}:9090" >/dev/null 2>&1 &
  PF_PID=$!
  for _ in $(seq 1 40); do
    curl -sf "http://localhost:${PROM_PORT}/-/ready" >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  echo "ERROR: could not reach Prometheus via port-forward" >&2
  exit 1
}

# promq <promql> <label> [format]  -> prints "label: value"
promq() {
  local q="$1" label="$2" fmt="${3:-ratio}"
  prom_forward
  local v
  v=$(curl -sG --data-urlencode "query=${q}" \
        "http://localhost:${PROM_PORT}/api/v1/query" \
      | jq -r '.data.result[0].value[1] // "no data"')
  if [[ "$v" == "no data" || "$v" == "null" ]]; then
    printf '  %-38s %s\n' "$label" "no data"
  elif [[ "$fmt" == "pct" ]]; then
    printf '  %-38s %s%%\n' "$label" "$(awk -v x="$v" 'BEGIN{printf "%.4f", x*100}')"
  elif [[ "$fmt" == "x" ]]; then
    printf '  %-38s %sx\n' "$label" "$(awk -v x="$v" 'BEGIN{printf "%.2f", x}')"
  else
    printf '  %-38s %s\n' "$label" "$(awk -v x="$v" 'BEGIN{printf "%.2f", x}')"
  fi
}

replicas() { kubectl get deploy slo-demo -n "$NS" -o jsonpath='{.spec.replicas}'; }

# The Service load-balances, so /chaos must be POSTed enough times to reach
# every replica with high probability.
set_chaos() {
  local qs="$1" n
  n=$(( $(replicas) * 10 ))
  echo "==> POST /chaos?${qs}   (x${n} writes to cover all replicas)"
  for _ in $(seq 1 "$n"); do curl -s -X POST "${APP_URL}/chaos?${qs}" -o /dev/null; done
  echo "==> resulting state, deduplicated across replicas:"
  for _ in $(seq 1 "$n"); do curl -s "${APP_URL}/chaos"; echo; done | sed '/^$/d' | sort -u | sed 's/^/  /'
}

show_status() {
  echo "================ slo-demo SLO status @ $(date -u '+%Y-%m-%dT%H:%M:%SZ') ================"
  echo "chaos state (deduplicated across replicas):"
  for _ in $(seq 1 30); do curl -s "${APP_URL}/chaos"; echo; done | sed '/^$/d' | sort -u | sed 's/^/  /'
  echo
  echo "traffic:"
  promq 'sum(rate(http_requests_total{job="slo-demo",path="/api"}[1m]))' 'request rate (req/s)'
  echo
  echo "availability SLI (error ratio, budget = 0.5%):"
  promq 'slo:availability_error:ratio_rate5m'  '5m  window' pct
  promq 'slo:availability_error:ratio_rate30m' '30m window' pct
  promq 'slo:availability_error:ratio_rate1h'  '1h  window' pct
  echo
  echo "latency SLI (ratio slower than 300ms, budget = 1%):"
  promq 'slo:latency_error:ratio_rate5m' '5m  window' pct
  promq 'slo:latency_error:ratio_rate1h' '1h  window' pct
  echo
  echo "burn rate (1 = budget spent exactly evenly over 28d):"
  promq 'slo:availability_burn_rate:1h' 'availability 1h' x
  promq 'slo:availability_burn_rate:6h' 'availability 6h' x
  echo
  echo "error budget remaining (6h lab proxy; 1.0 = untouched):"
  promq 'slo:availability_error_budget_remaining:ratio6h' 'availability'
  echo "=============================================================================="
}

show_alerts() {
  prom_forward
  echo "=== SLO alerts pending or firing @ $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
  curl -s "http://localhost:${PROM_PORT}/api/v1/rules?type=alert" \
    | jq -r '
        [ .data.groups[]
          | select(.name | startswith("slo-demo"))
          | .rules[]
          | select(.state != "inactive")
        ] as $a
        | if ($a | length) == 0 then "  (none — all SLO alerts inactive)"
          else $a[]
            | "  [\(.state | ascii_upcase)] \(.name)"
            + "\n      burn_rate=\(.labels.burn_rate)x  windows=\(.labels.long_window)/\(.labels.short_window)  severity=\(.labels.severity)"
            + "\n      active since: \([.alerts[]?.activeAt] | first // "n/a")"
            + "\n      value:        \([.alerts[]?.value] | first // "n/a")"
          end'
}

case "${1:-status}" in
  break)  set_chaos "error_rate=${2:-0.25}" ;;
  slow)   set_chaos "slow_rate=${2:-0.40}" ;;
  heal)   set_chaos "error_rate=0.001&slow_rate=0.005" ;;
  status) show_status ;;
  alerts) show_alerts ;;
  watch)  while true; do show_status; echo; show_alerts; echo; sleep 30; done ;;
  *)      sed -n '2,12p' "$0"; exit 1 ;;
esac
