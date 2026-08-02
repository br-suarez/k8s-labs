#!/usr/bin/env bash
#
# Game Day I — failure injection for modules 00-08.
#
# ############################################################################
# #  DO NOT READ THIS FILE BEFORE RUNNING IT.                                #
# #                                                                          #
# #  Reading it turns a diagnostic exercise into a reading exercise, and      #
# #  the whole point is that you do not know what broke. Run it, diagnose     #
# #  it, fix it, and only then come back and see whether you were right.     #
# ############################################################################
#
# Usage:
#   ./scripts/gameday-1.sh inject          # one random failure
#   ./scripts/gameday-1.sh inject 3        # three at once (harder)
#   ./scripts/gameday-1.sh status          # what is currently injected (spoiler)
#   ./scripts/gameday-1.sh restore         # undo everything
#
# Every injection is reversible. `restore` returns the cluster to health even
# if you have partially fixed things by hand.

set -euo pipefail

NS=${PULSE_NAMESPACE:-pulse}
MON_NS=${MONITORING_NAMESPACE:-monitoring}
STATE_DIR=${GAMEDAY_STATE:-/tmp/gameday-1}

readonly RED=$'\033[31m' GREEN=$'\033[32m' DIM=$'\033[2m' RESET=$'\033[0m'
log()  { printf '%s\n' "$*" >&2; }
die()  { log "${RED}error:${RESET} $*"; exit 1; }

mkdir -p "$STATE_DIR"

# --- helpers ------------------------------------------------------------------

need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found"; }

save() { # save <key> <content>
  printf '%s' "$2" > "$STATE_DIR/$1"
}

saved() { # saved <key>
  [ -f "$STATE_DIR/$1" ] && cat "$STATE_DIR/$1"
}

mark()   { touch "$STATE_DIR/active-$1"; }
unmark() { rm -f "$STATE_DIR/active-$1"; }
is_active() { [ -f "$STATE_DIR/active-$1" ]; }

# =============================================================================
# INJECTIONS
#
# Each is a pair: inject_N and restore_N. Keep them independent so several can
# run at once without interfering.
# =============================================================================

# --- 1: readiness probe points at the liveness endpoint ----------------------
# Symptom: requests fail during and shortly after any rollout. Everything green.
inject_1() {
  save 1-orig "$(kubectl get deployment pulse-api -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')"
  kubectl patch deployment pulse-api -n "$NS" --type=json -p \
    '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/healthz"}]' >/dev/null
  kubectl patch deployment pulse-api -n "$NS" --type=json -p \
    '[{"op":"replace","path":"/spec/strategy/rollingUpdate/maxSurge","value":3}]' >/dev/null 2>&1 || true
  mark 1
}
restore_1() {
  local p; p=$(saved 1-orig); p=${p:-/readyz}
  kubectl patch deployment pulse-api -n "$NS" --type=json -p \
    "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"$p\"}]" >/dev/null 2>&1 || true
  kubectl patch deployment pulse-api -n "$NS" --type=json -p \
    '[{"op":"replace","path":"/spec/strategy/rollingUpdate/maxSurge","value":1}]' >/dev/null 2>&1 || true
  unmark 1
}

# --- 2: Service selector no longer matches any pod ---------------------------
# Symptom: 503 from the gateway. Pods healthy. Endpoints empty.
inject_2() {
  save 2-orig "$(kubectl get svc pulse-api -n "$NS" -o jsonpath='{.spec.selector}')"
  kubectl patch svc pulse-api -n "$NS" --type=merge -p \
    '{"spec":{"selector":{"app":"pulse-api","tier":"backend-v2"}}}' >/dev/null
  mark 2
}
restore_2() {
  kubectl patch svc pulse-api -n "$NS" --type=merge -p \
    '{"spec":{"selector":{"app":"pulse-api"}}}' >/dev/null 2>&1 || true
  unmark 2
}

# --- 3: gateway stops admitting routes from this namespace -------------------
# Symptom: 404 from the gateway for everything. Route exists and looks fine.
inject_3() {
  local gw; gw=$(kubectl get gateway -n "$NS" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -n "$gw" ] || { log "${DIM}skipping 3: no Gateway found${RESET}"; return; }
  save 3-gw "$gw"
  save 3-orig "$(kubectl get gateway "$gw" -n "$NS" \
    -o jsonpath='{.spec.listeners[0].allowedRoutes.namespaces.from}')"
  kubectl patch gateway "$gw" -n "$NS" --type=json -p \
    '[{"op":"replace","path":"/spec/listeners/0/allowedRoutes/namespaces/from","value":"Selector"},
      {"op":"add","path":"/spec/listeners/0/allowedRoutes/namespaces/selector","value":{"matchLabels":{"gateway-access":"nonexistent"}}}]' >/dev/null \
    || die "could not patch gateway $gw — inspect it by hand"
  mark 3
}
restore_3() {
  local gw; gw=$(saved 3-gw)
  [ -n "$gw" ] || { unmark 3; return; }
  local orig; orig=$(saved 3-orig); orig=${orig:-Same}
  kubectl patch gateway "$gw" -n "$NS" --type=json -p \
    "[{\"op\":\"replace\",\"path\":\"/spec/listeners/0/allowedRoutes/namespaces/from\",\"value\":\"$orig\"},
      {\"op\":\"remove\",\"path\":\"/spec/listeners/0/allowedRoutes/namespaces/selector\"}]" >/dev/null 2>&1 || true
  unmark 3
}

# --- 4: memory limit below working set ---------------------------------------
# Symptom: worker restarts on a loop. Exit 137. Queue depth climbs.
inject_4() {
  save 4-orig "$(kubectl get deployment pulse-worker -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')"
  kubectl set resources deployment pulse-worker -n "$NS" \
    --limits=memory=24Mi >/dev/null
  mark 4
}
restore_4() {
  local m; m=$(saved 4-orig); m=${m:-256Mi}
  kubectl set resources deployment pulse-worker -n "$NS" --limits=memory="$m" >/dev/null 2>&1 || true
  unmark 4
}

# --- 5: worker points at a hostname that does not resolve --------------------
# Symptom: no new results. Worker healthy, no restarts, logs a DNS error.
inject_5() {
  save 5-orig "$(kubectl get deployment pulse-worker -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PULSE_API_URL")].value}')"
  kubectl set env deployment/pulse-worker -n "$NS" \
    PULSE_API_URL=http://pulse-api.pulse-backend.svc.cluster.local:8080 >/dev/null
  mark 5
}
restore_5() {
  local u; u=$(saved 5-orig); u=${u:-http://pulse-api:8080}
  kubectl set env deployment/pulse-worker -n "$NS" PULSE_API_URL="$u" >/dev/null 2>&1 || true
  unmark 5
}

# --- 6: worker concurrency collapsed -----------------------------------------
# Symptom: queue depth climbs steadily, jobs dropped, SLO burns. Nothing errors.
inject_6() {
  save 6-conc "$(kubectl get deployment pulse-worker -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WORKER_CONCURRENCY")].value}')"
  save 6-queue "$(kubectl get deployment pulse-worker -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="QUEUE_SIZE")].value}')"
  kubectl set env deployment/pulse-worker -n "$NS" \
    WORKER_CONCURRENCY=1 QUEUE_SIZE=4 SCHEDULE_INTERVAL_SECONDS=2 >/dev/null
  mark 6
}
restore_6() {
  local c q; c=$(saved 6-conc); q=$(saved 6-queue)
  kubectl set env deployment/pulse-worker -n "$NS" \
    WORKER_CONCURRENCY="${c:-4}" QUEUE_SIZE="${q:-64}" SCHEDULE_INTERVAL_SECONDS=15 >/dev/null 2>&1 || true
  unmark 6
}

readonly TOTAL=6

# =============================================================================

cmd_inject() {
  local count=${1:-1}
  need kubectl
  kubectl get namespace "$NS" >/dev/null 2>&1 || die "namespace $NS not found"

  [ "$count" -ge 1 ] && [ "$count" -le "$TOTAL" ] || die "count must be 1-$TOTAL"

  # Pick `count` distinct injections at random.
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
  log "${RED}==============================================${RESET}"
  log "${RED}  ${#picked[@]} failure(s) injected. Timer starts now.${RESET}"
  log "${RED}==============================================${RESET}"
  log ""
  log "Rules:"
  log "  1. Record every command you run, in order."
  log "  2. Mitigate first, root-cause second."
  log "  3. Write the postmortem in the same session."
  log ""
  log "${DIM}Do not read this script. Run: $0 restore  when finished.${RESET}"
}

cmd_status() {
  log "${DIM}(this is a spoiler — only for after the exercise)${RESET}"
  local n any=0
  for n in $(seq 1 $TOTAL); do
    if is_active "$n"; then log "  ${RED}active${RESET}  injection $n"; any=1; fi
  done
  [ "$any" -eq 1 ] || log "  ${GREEN}nothing injected${RESET}"
}

cmd_restore() {
  need kubectl
  local n
  for n in $(seq 1 $TOTAL); do
    "restore_$n" 2>/dev/null || true
  done
  rm -rf "${STATE_DIR:?}"/active-* 2>/dev/null || true

  log "${GREEN}restored.${RESET} Waiting for rollout..."
  kubectl rollout status deployment/pulse-api -n "$NS" --timeout=90s || true
  kubectl rollout status deployment/pulse-worker -n "$NS" --timeout=90s || true
  log ""
  log "Verify with: ./platform/scripts/verify.sh"
}

case "${1:-}" in
  inject)  shift; cmd_inject "$@" ;;
  status)  cmd_status ;;
  restore) cmd_restore ;;
  *)
    log "usage: $0 {inject [count] | status | restore}"
    exit 2 ;;
esac
