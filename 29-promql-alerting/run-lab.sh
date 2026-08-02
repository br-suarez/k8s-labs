#!/usr/bin/env bash
# Run the four queries against live Prometheus, demonstrate two classic PromQL
# mistakes side by side with the correct form, then force an alert to fire.
set -uo pipefail

cd "$(dirname "$0")"
OUT=./evidence
mkdir -p "$OUT"
PORT=${PORT:-9110}
APP_URL=${APP_URL:-http://localhost:30080}

PF_PID=""
cleanup() {
  [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true
  echo "==> restoring service to baseline"
  for _ in $(seq 1 30); do
    curl -s -X POST "${APP_URL}/chaos?error_rate=0.001&slow_rate=0.005" -o /dev/null
  done
}
trap cleanup EXIT

kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus "${PORT}:9090" >/dev/null 2>&1 &
PF_PID=$!
for _ in $(seq 1 40); do
  curl -sf "http://localhost:${PORT}/-/ready" >/dev/null 2>&1 && break
  sleep 0.25
done

hdr() { printf '\n========== %s ==========\n' "$*"; }

# q <label> <promql> [format]
q() {
  local label="$1" query="$2" fmt="${3:-raw}"
  printf '\n--- %s\n' "$label"
  printf 'promql: %s\n' "$(echo "$query" | tr -s ' \n' ' ')"
  curl -sG --data-urlencode "query=${query}" "http://localhost:${PORT}/api/v1/query" \
    | jq -r --arg f "$fmt" '
        if (.data.result | length) == 0 then "  (empty result)"
        else .data.result[] |
          ((.metric | to_entries | map("\(.key)=\(.value)") | join(",")) as $m |
           (if $f == "pct" then "\((.value[1] | tonumber) * 100 | . * 1000 | round / 1000)%"
            elif $f == "ms" then "\((.value[1] | tonumber) * 1000 | . * 100 | round / 100)ms"
            else (.value[1] | tonumber | . * 1000 | round / 1000 | tostring) end) as $v |
           "  \(if $m == "" then "(no labels)" else $m end)  =>  \($v)")
        end'
}

alerts() {
  curl -s "http://localhost:${PORT}/api/v1/rules?type=alert" | jq -r '
    [.data.groups[] | select(.name | startswith("slo-demo.latency")) | .rules[]] as $a
    | if ($a|length) == 0 then "  (no rules loaded yet)"
      else $a[] | "  [\(.state|ascii_upcase)] \(.name)  value=\([.alerts[]?.value]|first // "n/a")"
      end'
}

{
echo "======================================================================"
echo " PROMQL — the four queries, two classic mistakes, one forced alert"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

hdr "1. RATE — throughput by status"
q "requests/sec by status" 'sum by (status) (rate(http_requests_total{job="slo-demo",path="/api"}[1m]))'

hdr "2. ERRORS — failure ratio"
q "error ratio (5m)" 'sum(rate(http_requests_total{job="slo-demo",path="/api",status=~"5.."}[5m])) / sum(rate(http_requests_total{job="slo-demo",path="/api"}[5m]))' pct

hdr "3. DURATION — p50 / p90 / p99"
q "p50" 'histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{job="slo-demo",path="/api"}[5m])))' ms
q "p90" 'histogram_quantile(0.90, sum by (le) (rate(http_request_duration_seconds_bucket{job="slo-demo",path="/api"}[5m])))' ms
q "p99" 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{job="slo-demo",path="/api"}[5m])))' ms

hdr "4. SATURATION — memory vs limit, and CPU throttling"
q "memory working set / limit" 'max by (pod) (container_memory_working_set_bytes{namespace="slo-demo",container="slo-demo"} / on (pod,container) kube_pod_container_resource_limits{namespace="slo-demo",container="slo-demo",resource="memory"})' pct
q "CPU throttled periods ratio" 'sum by (pod) (rate(container_cpu_cfs_throttled_periods_total{namespace="slo-demo"}[5m])) / sum by (pod) (rate(container_cpu_cfs_periods_total{namespace="slo-demo"}[5m]))' pct

hdr "MISTAKE 1 — histogram_quantile without 'by (le)'"
echo "
The correct form aggregates buckets while KEEPING the le label:"
q "correct: sum by (le)" 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{job="slo-demo",path="/api"}[5m])))' ms
echo "
Dropping 'by (le)' removes the only label the function can interpolate over:"
q "wrong: bare sum" 'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{job="slo-demo",path="/api"}[5m])))' ms

hdr "MISTAKE 2 — rate(sum(...)) instead of sum(rate(...))"
echo "
Correct — rate each pod's counter, then add the per-second results:"
q "correct: sum(rate(...))" 'sum(rate(http_requests_total{job="slo-demo",path="/api"}[5m]))'
echo "
Wrong — adding raw counters first. It happens to look plausible while every pod
is up; the moment one restarts, the summed counter drops and rate() reads the
reset as a real decrease. Same shape, silently wrong exactly during an incident:"
q "wrong: rate(sum(...))" 'rate(sum(http_requests_total{job="slo-demo",path="/api"})[5m:15s])'

hdr "Loading the alert rules"
kubectl apply -f alerts.yaml
sleep 45
echo "Alert state at baseline:"
alerts

# ------------------------------------------------------------ force it
hdr "FORCING THE ALERT — inject latency"
echo "
Setting slow_rate=0.60: 60% of requests take 320-700ms, which drags p99 well
above the 300ms objective."
for _ in $(seq 1 30); do curl -s -X POST "${APP_URL}/chaos?slow_rate=0.60" -o /dev/null; done
curl -s "${APP_URL}/chaos"; echo

for i in $(seq 1 20); do
  printf '\n[poll %s @ %s]\n' "$i" "$(date -u '+%H:%M:%SZ')"
  q "p99" 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{job="slo-demo",path="/api"}[5m])))' ms
  alerts
  STATE=$(curl -s "http://localhost:${PORT}/api/v1/rules?type=alert" \
          | jq -r '[.data.groups[].rules[] | select(.name=="SLODemoHighLatencyP99")][0].state // "unknown"')
  [[ "$STATE" == "firing" ]] && { echo; echo ">>> SLODemoHighLatencyP99 is FIRING at $(date -u '+%H:%M:%SZ')"; break; }
  sleep 30
done

hdr "RECOVERY — restore baseline and watch it clear"
for _ in $(seq 1 30); do curl -s -X POST "${APP_URL}/chaos?slow_rate=0.005" -o /dev/null; done
for i in $(seq 1 14); do
  printf '\n[recovery poll %s @ %s]\n' "$i" "$(date -u '+%H:%M:%SZ')"
  q "p99" 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{job="slo-demo",path="/api"}[5m])))' ms
  alerts
  STATE=$(curl -s "http://localhost:${PORT}/api/v1/rules?type=alert" \
          | jq -r '[.data.groups[].rules[] | select(.name=="SLODemoHighLatencyP99")][0].state // "unknown"')
  [[ "$STATE" == "inactive" ]] && { echo; echo ">>> back to inactive at $(date -u '+%H:%M:%SZ')"; break; }
  sleep 30
done
} | tee "$OUT/01-queries-and-alert.txt"

echo
echo "Evidence written to ${OUT}/"
