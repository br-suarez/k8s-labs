#!/usr/bin/env bash
# Re-test scenario A after tuning the first pause from 90s to 180s.
#
# The original run proved the gate rejects a bad release, but the canary reached
# 60% weight before the analysis reached a verdict. This run proves the fix:
# with the pause longer than the analysis time-to-verdict, the rollout must
# abort while still at 20%.
#
# Records the maximum canary weight reached — that number IS the result.
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="${HOME}/.local/bin:${PATH}"

NS=canary-demo
OUT=./evidence
ROLLOUT=slo-demo

ts() { date -u '+%H:%M:%SZ'; }
say() { printf '\n\033[1;36m[%s] %s\033[0m\n' "$(ts)" "$*"; }

say "Publishing tuned rollout (pause 180s) + slo-demo:v2-bad"
{
  echo "BLAST RADIUS RETEST — first pause 90s -> 180s, redeploying v2-bad"
  echo
  IMAGE=slo-demo:v2-bad ./gitops-app/publish.sh "Tune canary pause to 180s and retry v2"
} | tee "$OUT/08-retest-push.txt"

kubectl -n argocd annotate app slo-demo argocd.argoproj.io/refresh=hard --overwrite >/dev/null
sleep 8

# Canary weight, measured from reality rather than from status.canary.weights.
#
# That field stays EMPTY ({}) for a replica-based canary — it is only populated
# when a traffic router (Istio, NGINX, ALB) is managing the split. With no
# router, Argo Rollouts implements the weight by changing how many pods each
# ReplicaSet runs, so the honest measurement is the canary ReplicaSet's share of
# the pods. The first version of this script read the empty field and reported
# 0% for the whole run.
canary_weight() {
  local hash total canary
  hash=$(kubectl get rollout "$ROLLOUT" -n "$NS" -o jsonpath='{.status.currentPodHash}' 2>/dev/null)
  total=$(kubectl get rollout "$ROLLOUT" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  [[ -z "$hash" || -z "$total" || "$total" -eq 0 ]] && { echo 0; return; }
  canary=$(kubectl get rs -n "$NS" -l "rollouts-pod-template-hash=${hash}" \
           -o jsonpath='{.items[0].status.replicas}' 2>/dev/null)
  canary=${canary:-0}
  echo $(( canary * 100 / total ))
}

say "Watching — recording max canary weight"
: > "$OUT/09-retest-progression.txt"
MAX_WEIGHT=0
for i in $(seq 1 40); do
  PHASE=$(kubectl get rollout "$ROLLOUT" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  STEP=$(kubectl get rollout "$ROLLOUT" -n "$NS" -o jsonpath='{.status.currentStepIndex}' 2>/dev/null || echo "-")
  WEIGHT=$(canary_weight)
  [[ "$WEIGHT" =~ ^[0-9]+$ ]] && (( WEIGHT > MAX_WEIGHT )) && MAX_WEIGHT=$WEIGHT

  {
    echo "----- poll #$i @ $(ts) --  phase=${PHASE}  step=${STEP}  canary_weight=${WEIGHT}%  max_so_far=${MAX_WEIGHT}%"
  } | tee -a "$OUT/09-retest-progression.txt"

  if [[ "$PHASE" == "Degraded" ]]; then
    say "Aborted. Maximum canary weight reached: ${MAX_WEIGHT}%"
    {
      echo "BLAST RADIUS RETEST RESULT"
      echo
      echo "maximum canary weight reached before abort: ${MAX_WEIGHT}%"
      echo "(previous run with a 90s pause reached 60%)"
      echo
      kubectl argo rollouts get rollout "$ROLLOUT" -n "$NS" --no-color
      echo
      echo "measurements:"
      RUN=$(kubectl get analysisrun -n "$NS" --sort-by=.metadata.creationTimestamp \
            -o jsonpath='{.items[-1:].metadata.name}')
      kubectl get analysisrun "$RUN" -n "$NS" -o json | jq -r '
        .status.metricResults[]? |
        "  metric=\(.name) phase=\(.phase) successful=\(.successful // 0) failed=\(.failed // 0)",
        (.measurements[]? | "    [\(.phase)] value=\(.value // "n/a")  at \(.startedAt)")'
    } | tee "$OUT/10-retest-result.txt"
    break
  fi
  sleep 15
done

say "Restoring the good release (v3-fixed)"
IMAGE=slo-demo:v3-fixed ./gitops-app/publish.sh "Restore v3-fixed after blast radius retest" \
  | tee "$OUT/11-restore-v3.txt"
kubectl -n argocd annotate app slo-demo argocd.argoproj.io/refresh=hard --overwrite >/dev/null

say "Done."
