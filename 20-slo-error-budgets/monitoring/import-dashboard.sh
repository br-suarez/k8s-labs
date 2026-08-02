#!/usr/bin/env bash
# Import grafana-slo-dashboard.json into the Grafana shipped by kube-prometheus-stack.
#
# The dashboard JSON references its datasource as "${datasource}". Grafana's API
# does not resolve dashboard variables at import time, so the placeholder is
# rewritten to the real Prometheus datasource UID — which is generated per
# install and therefore cannot be hardcoded in the committed JSON.
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


cd "$(dirname "$0")"

NS=monitoring
GRAFANA_SVC=svc/kube-prom-stack-grafana
PORT=${PORT:-3000}
USER=admin
PASS=${GRAFANA_PASS:-slolab}
SRC=grafana-slo-dashboard.json

PF_PID=""
cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

kubectl port-forward -n "$NS" "$GRAFANA_SVC" "${PORT}:80" >/dev/null 2>&1 &
PF_PID=$!

for _ in $(seq 1 40); do
  curl -sf "http://localhost:${PORT}/api/health" >/dev/null 2>&1 && break
  sleep 0.25
done

DS_UID=$(curl -s -u "${USER}:${PASS}" "http://localhost:${PORT}/api/datasources" \
         | jq -r 'map(select(.type=="prometheus")) | .[0].uid')
echo "==> Prometheus datasource UID: ${DS_UID}"

jq --arg uid "$DS_UID" '
    walk(if type == "object" and .uid == "${datasource}" then .uid = $uid else . end)
    | del(.templating)
    | { dashboard: (. + {id: null}), overwrite: true, folderId: 0 }
' "$SRC" > /tmp/slo-dashboard-import.json

echo "==> Importing ${SRC}"
curl -s -u "${USER}:${PASS}" -H "Content-Type: application/json" \
     -X POST -d @/tmp/slo-dashboard-import.json \
     "http://localhost:${PORT}/api/dashboards/db" | jq .

cat <<EOF

==> Open it with:
      kubectl port-forward -n ${NS} ${GRAFANA_SVC} ${PORT}:80
      http://localhost:${PORT}/d/slo-demo-errorbudget   (${USER} / ${PASS})
EOF
