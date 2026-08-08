#!/usr/bin/env bash
#
# Game Day II — failure injection across the full platform (modules 00-15).
#
# ############################################################################
# #  DO NOT READ THIS FILE BEFORE RUNNING IT.                                #
# #                                                                          #
# #  You read gameday-1.sh after the exercise. Do the same here. Knowing     #
# #  the catalogue in advance turns diagnosis into recall.                   #
# ############################################################################
#
# Usage:
#   ./scripts/gameday-2.sh inject          # one random failure
#   ./scripts/gameday-2.sh inject 5        # five at once — the module 16 target
#   ./scripts/gameday-2.sh status          # spoiler
#   ./scripts/gameday-2.sh restore
#
# Every injection is reversible. Unlike Game Day I, several of these interact:
# one failure can mask another, and the order you fix them matters.

set -euo pipefail

NS=${PULSE_NAMESPACE:-pulse}
MON_NS=${MONITORING_NAMESPACE:-monitoring}
ARGO_NS=${ARGOCD_NAMESPACE:-argocd}
STATE_DIR=${GAMEDAY_STATE:-/tmp/gameday-2}

readonly RED=$'\033[31m' GREEN=$'\033[32m' DIM=$'\033[2m' RESET=$'\033[0m'
log() { printf '%s\n' "$*" >&2; }
die() { log "${RED}error:${RESET} $*"; exit 1; }

mkdir -p "$STATE_DIR"
save()      { printf '%s' "$2" > "$STATE_DIR/$1"; }
saved()     { [ -f "$STATE_DIR/$1" ] && cat "$STATE_DIR/$1"; }
mark()      { touch "$STATE_DIR/active-$1"; }
unmark()    { rm -f "$STATE_DIR/active-$1"; }
is_active() { [ -f "$STATE_DIR/active-$1" ]; }
have()      { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# INJECTIONS — one per layer of the platform
# =============================================================================

# --- 1: probe pointed at the wrong endpoint (module 04) ----------------------
inject_1() {
  save 1-orig "$(kubectl get deployment pulse-api -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')"
  kubectl patch deployment pulse-api -n "$NS" --type=json -p \
    '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/healthz"}]' >/dev/null
  mark 1
}
restore_1() {
  local p; p=$(saved 1-orig); p=${p:-/readyz}
  kubectl patch deployment pulse-api -n "$NS" --type=json -p \
    "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"$p\"}]" >/dev/null 2>&1 || true
  unmark 1
}

# --- 2: gateway stops admitting routes (module 05) ---------------------------
inject_2() {
  local gw; gw=$(kubectl get gateway -n "$NS" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -n "$gw" ] || { log "${DIM}skip 2: no Gateway${RESET}"; return; }
  save 2-gw "$gw"
  save 2-orig "$(kubectl get gateway "$gw" -n "$NS" \
    -o jsonpath='{.spec.listeners[0].allowedRoutes.namespaces.from}')"
  kubectl patch gateway "$gw" -n "$NS" --type=json -p \
    '[{"op":"replace","path":"/spec/listeners/0/allowedRoutes/namespaces/from","value":"Selector"},
      {"op":"add","path":"/spec/listeners/0/allowedRoutes/namespaces/selector","value":{"matchLabels":{"gateway-access":"none"}}}]' >/dev/null
  mark 2
}
restore_2() {
  local gw; gw=$(saved 2-gw); [ -n "$gw" ] || { unmark 2; return; }
  local o; o=$(saved 2-orig); o=${o:-Same}
  kubectl patch gateway "$gw" -n "$NS" --type=json -p \
    "[{\"op\":\"replace\",\"path\":\"/spec/listeners/0/allowedRoutes/namespaces/from\",\"value\":\"$o\"},
      {\"op\":\"remove\",\"path\":\"/spec/listeners/0/allowedRoutes/namespaces/selector\"}]" >/dev/null 2>&1 || true
  unmark 2
}

# --- 3: cardinality explosion (module 07) ------------------------------------
# Prometheus degrades slowly rather than failing, so this one masks others.
inject_3() {
  save 3-orig "$(kubectl get deployment pulse-worker -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="METRIC_LABEL_MODE")].value}')"
  kubectl set env deployment/pulse-worker -n "$NS" METRIC_LABEL_MODE=per-url >/dev/null
  mark 3
}
restore_3() {
  local o; o=$(saved 3-orig)
  if [ -n "$o" ]; then
    kubectl set env deployment/pulse-worker -n "$NS" METRIC_LABEL_MODE="$o" >/dev/null 2>&1 || true
  else
    kubectl set env deployment/pulse-worker -n "$NS" METRIC_LABEL_MODE- >/dev/null 2>&1 || true
  fi
  unmark 3
}

# --- 4: collector processors in the wrong order (module 08) ------------------
inject_4() {
  kubectl get configmap otel-collector-config -n "$MON_NS" >/dev/null 2>&1 \
    || { log "${DIM}skip 4: no collector config${RESET}"; return; }
  kubectl get configmap otel-collector-config -n "$MON_NS" -o yaml > "$STATE_DIR/4-orig.yaml"
  kubectl get configmap otel-collector-config -n "$MON_NS" -o yaml \
    | sed 's/\[memory_limiter, batch\]/[batch, memory_limiter]/' \
    | kubectl apply -f - >/dev/null
  kubectl rollout restart daemonset/otel-collector -n "$MON_NS" >/dev/null 2>&1 || true
  mark 4
}
restore_4() {
  [ -f "$STATE_DIR/4-orig.yaml" ] && kubectl apply -f "$STATE_DIR/4-orig.yaml" >/dev/null 2>&1 || true
  kubectl rollout restart daemonset/otel-collector -n "$MON_NS" >/dev/null 2>&1 || true
  unmark 4
}

# --- 5: self-heal reverting a fix (module 10) --------------------------------
# The most confusing one: a fix that works and then undoes itself.
inject_5() {
  kubectl get application pulse -n "$ARGO_NS" >/dev/null 2>&1 \
    || { log "${DIM}skip 5: no Argo Application${RESET}"; return; }
  save 5-mem "$(kubectl get deployment pulse-api -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')"
  kubectl set resources deployment pulse-api -n "$NS" --limits=memory=32Mi >/dev/null
  kubectl patch application pulse -n "$ARGO_NS" --type=merge -p \
    '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}' >/dev/null
  mark 5
}
restore_5() {
  local m; m=$(saved 5-mem); m=${m:-256Mi}
  kubectl set resources deployment pulse-api -n "$NS" --limits=memory="$m" >/dev/null 2>&1 || true
  unmark 5
}

# --- 6: canary analysis not scoped to the canary (module 11) -----------------
inject_6() {
  kubectl get analysistemplate error-rate -n "$NS" >/dev/null 2>&1 \
    || { log "${DIM}skip 6: no AnalysisTemplate${RESET}"; return; }
  kubectl get analysistemplate error-rate -n "$NS" -o yaml > "$STATE_DIR/6-orig.yaml"
  kubectl get analysistemplate error-rate -n "$NS" -o yaml \
    | sed 's/rollouts_pod_template_hash="{{args.canary-hash}}"//g' \
    | kubectl apply -f - >/dev/null
  mark 6
}
restore_6() {
  [ -f "$STATE_DIR/6-orig.yaml" ] && kubectl apply -f "$STATE_DIR/6-orig.yaml" >/dev/null 2>&1 || true
  unmark 6
}

# --- 7: admission policy silently permitting (module 12) ---------------------
inject_7() {
  kubectl get clusterpolicy require-signed-images >/dev/null 2>&1 \
    || { log "${DIM}skip 7: no policy${RESET}"; return; }
  save 7-orig "$(kubectl get clusterpolicy require-signed-images \
    -o jsonpath='{.spec.validationFailureAction}')"
  kubectl patch clusterpolicy require-signed-images --type=merge -p \
    '{"spec":{"validationFailureAction":"Audit"}}' >/dev/null
  mark 7
}
restore_7() {
  local o; o=$(saved 7-orig); o=${o:-Enforce}
  kubectl patch clusterpolicy require-signed-images --type=merge -p \
    "{\"spec\":{\"validationFailureAction\":\"$o\"}}" >/dev/null 2>&1 || true
  unmark 7
}

# --- 8: queue saturation (modules 07-08) -------------------------------------
inject_8() {
  save 8-conc "$(kubectl get deployment pulse-worker -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WORKER_CONCURRENCY")].value}')"
  kubectl set env deployment/pulse-worker -n "$NS" \
    WORKER_CONCURRENCY=1 QUEUE_SIZE=8 SCHEDULE_INTERVAL_SECONDS=2 >/dev/null
  mark 8
}
restore_8() {
  local c; c=$(saved 8-conc)
  kubectl set env deployment/pulse-worker -n "$NS" \
    WORKER_CONCURRENCY="${c:-4}" QUEUE_SIZE=64 SCHEDULE_INTERVAL_SECONDS=15 >/dev/null 2>&1 || true
  unmark 8
}

# --- 9: TCP accept queue too small (module 08b) ------------------------------
# Application p99 stays fast; clients see seconds. Invisible above the socket.
inject_9() {
  save 9-orig "$(kubectl get deployment pulse-api -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="LISTEN_BACKLOG")].value}')"
  kubectl set env deployment/pulse-api -n "$NS" LISTEN_BACKLOG=2 >/dev/null
  mark 9
}
restore_9() {
  local o; o=$(saved 9-orig)
  if [ -n "$o" ]; then
    kubectl set env deployment/pulse-api -n "$NS" LISTEN_BACKLOG="$o" >/dev/null 2>&1 || true
  else
    kubectl set env deployment/pulse-api -n "$NS" LISTEN_BACKLOG- >/dev/null 2>&1 || true
  fi
  unmark 9
}

# --- 10: PDB that blocks all maintenance (module 06) -------------------------
inject_10() {
  local reps; reps=$(kubectl get deployment pulse-api -n "$NS" -o jsonpath='{.spec.replicas}')
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pulse-api-gameday
  namespace: $NS
spec:
  minAvailable: ${reps:-3}
  selector:
    matchLabels:
      app: pulse-api
EOF
  mark 10
}
restore_10() {
  kubectl delete pdb pulse-api-gameday -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
  unmark 10
}

readonly TOTAL=10

# =============================================================================

cmd_inject() {
  local count=${1:-1}
  have kubectl || die "kubectl not found"
  kubectl get namespace "$NS" >/dev/null 2>&1 || die "namespace $NS not found"
  [ "$count" -ge 1 ] && [ "$count" -le "$TOTAL" ] || die "count must be 1-$TOTAL"

  local picked=()
  while [ ${#picked[@]} -lt "$count" ]; do
    local n=$(( (RANDOM % TOTAL) + 1 ))
    printf '%s\n' "${picked[@]:-}" | grep -qx "$n" || picked+=("$n")
  done

  local n
  for n in "${picked[@]}"; do
    is_active "$n" || "inject_$n"
  done

  log ""
  log "${RED}================================================${RESET}"
  log "${RED}  ${#picked[@]} failure(s) injected. Timer starts now.${RESET}"
  log "${RED}================================================${RESET}"
  log ""
  log "Some of these interact. One can mask another, and the order you fix"
  log "them changes what you can observe."
  log ""
  log "  1. Record every command, with your hypothesis before running it."
  log "  2. Mitigate first, root-cause second."
  log "  3. Write the postmortem in this session."
  log ""
  log "${DIM}Do not read this script. Finish with: $0 restore${RESET}"
}

cmd_status() {
  log "${DIM}(spoiler — only after the exercise)${RESET}"
  local n any=0
  for n in $(seq 1 $TOTAL); do
    if is_active "$n"; then log "  ${RED}active${RESET}  injection $n"; any=1; fi
  done
  [ "$any" -eq 1 ] || log "  ${GREEN}nothing injected${RESET}"
}

cmd_restore() {
  have kubectl || die "kubectl not found"
  local n
  for n in $(seq 1 $TOTAL); do "restore_$n" 2>/dev/null || true; done
  rm -rf "${STATE_DIR:?}"/active-* 2>/dev/null || true

  log "${GREEN}restored.${RESET} Waiting for rollout..."
  kubectl rollout status deployment/pulse-api -n "$NS" --timeout=120s || true
  kubectl rollout status deployment/pulse-worker -n "$NS" --timeout=120s || true
  log ""
  log "Verify with: ./platform/scripts/verify.sh"
}

case "${1:-}" in
  inject)  shift; cmd_inject "$@" ;;
  status)  cmd_status ;;
  restore) cmd_restore ;;
  *) log "usage: $0 {inject [count] | status | restore}"; exit 2 ;;
esac
