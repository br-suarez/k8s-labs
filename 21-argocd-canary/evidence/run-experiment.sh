#!/usr/bin/env bash
# Two deploys, one gate.
#
#   Scenario A — ship slo-demo:v2-bad (20% errors). The SLO analysis must fail
#                and the Rollout must abort and roll back on its own.
#   Scenario B — ship slo-demo:v3-fixed. The same gate must let it through,
#                proving it measures the release rather than blocking everything.
#
# Run from the module root:  ./evidence/run-experiment.sh
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


cd "$(dirname "$0")/.."
export PATH="${HOME}/.local/bin:${PATH}"

NS=canary-demo
OUT=./evidence
ROLLOUT=slo-demo
APP=slo-demo

ts() { date -u '+%H:%M:%SZ'; }
say() { printf '\n\033[1;36m[%s] %s\033[0m\n' "$(ts)" "$*"; }

rollout_status() { kubectl argo rollouts get rollout "$ROLLOUT" -n "$NS" --no-color 2>/dev/null; }

analysis_status() {
  kubectl get analysisrun -n "$NS" \
    -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,STARTED:.status.startedAt' \
    --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -5
}

measurements() {
  # The individual measurements are the actual proof: each one is a PromQL
  # result compared against the successCondition.
  local run
  run=$(kubectl get analysisrun -n "$NS" --sort-by=.metadata.creationTimestamp \
        -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true)
  [[ -z "$run" ]] && { echo "  (no analysisrun yet)"; return; }
  echo "  analysisrun: $run"
  kubectl get analysisrun "$run" -n "$NS" -o json 2>/dev/null | jq -r '
    .status.metricResults[]? |
    "  metric=\(.name) phase=\(.phase) successful=\(.successful // 0) failed=\(.failed // 0) error=\(.error // 0)",
    (.measurements[]? | "    [\(.phase)] value=\(.value // "n/a")  at \(.startedAt)")'
}

# Argo CD polls Git every 3 minutes. A hard refresh makes the lab observable in
# real time instead of adding a random 0-180s wait to every step.
force_sync() {
  kubectl -n argocd annotate app "$APP" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  sleep 8
}

app_state() {
  kubectl get app "$APP" -n argocd \
    -o custom-columns='SYNC:.status.sync.status,HEALTH:.status.health.status,REV:.status.sync.revision' \
    --no-headers 2>/dev/null
}

# ------------------------------------------------------------------ baseline
say "Baseline — stable v1, no rollout in progress"
{
  echo "BASELINE"
  echo
  echo "argocd application: $(app_state)"
  echo
  rollout_status
} | tee "$OUT/01-baseline-v1.txt"

# --------------------------------------------------- scenario A: bad release
say "Scenario A — pushing slo-demo:v2-bad to Git"
{
  echo "SCENARIO A — DEPLOY slo-demo:v2-bad (20% error rate)"
  echo
  IMAGE=slo-demo:v2-bad ./gitops-app/publish.sh "Release v2: canary must reject this"
} | tee "$OUT/02-push-v2-bad.txt"

force_sync

say "Watching the canary analysis"
: > "$OUT/03-v2-bad-progression.txt"
ABORTED=0
for i in $(seq 1 24); do
  {
    echo "----- poll #$i @ $(ts) -----"
    echo "argocd: $(app_state)"
    echo
    rollout_status
    echo
    echo "analysis runs:"
    analysis_status
    echo
    echo "measurements:"
    measurements
    echo
  } | tee -a "$OUT/03-v2-bad-progression.txt"

  STATUS=$(kubectl get rollout "$ROLLOUT" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "$STATUS" == "Degraded" ]]; then
    say "Rollout is Degraded — canary rejected (poll #$i)"
    { echo "SCENARIO A RESULT — CANARY REJECTED, ROLLED BACK"; echo
      echo "argocd: $(app_state)"; echo
      rollout_status; echo; echo "measurements:"; measurements; echo
      echo "pods now serving:"
      kubectl get pods -n "$NS" -l app=slo-demo -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].image}{"\n"}{end}'
    } | tee "$OUT/04-v2-bad-rejected.txt"
    ABORTED=1
    break
  fi
  sleep 20
done

[[ "$ABORTED" -eq 0 ]] && echo "WARNING: rollout did not abort within polling budget" \
  | tee -a "$OUT/03-v2-bad-progression.txt"

# -------------------------------------------------- scenario B: good release
say "Scenario B — pushing slo-demo:v3-fixed to Git"
{
  echo "SCENARIO B — DEPLOY slo-demo:v3-fixed (baseline error rate)"
  echo
  IMAGE=slo-demo:v3-fixed ./gitops-app/publish.sh "Release v3: fixes the v2 regression"
} | tee "$OUT/05-push-v3-fixed.txt"

force_sync

say "Watching the good release promote"
: > "$OUT/06-v3-fixed-progression.txt"
for i in $(seq 1 30); do
  {
    echo "----- poll #$i @ $(ts) -----"
    rollout_status
    echo
    echo "measurements:"
    measurements
    echo
  } | tee -a "$OUT/06-v3-fixed-progression.txt"

  PHASE=$(kubectl get rollout "$ROLLOUT" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  IMG=$(kubectl get rollout "$ROLLOUT" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
  if [[ "$PHASE" == "Healthy" && "$IMG" == "slo-demo:v3-fixed" ]]; then
    say "v3-fixed fully promoted (poll #$i)"
    { echo "SCENARIO B RESULT — CANARY ACCEPTED, PROMOTED TO 100%"; echo
      echo "argocd: $(app_state)"; echo
      rollout_status; echo; echo "measurements:"; measurements; echo
      echo "pods now serving:"
      kubectl get pods -n "$NS" -l app=slo-demo -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].image}{"\n"}{end}'
    } | tee "$OUT/07-v3-fixed-promoted.txt"
    break
  fi
  sleep 20
done

say "Done. Evidence in $OUT/"
ls -la "$OUT"
