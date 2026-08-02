#!/usr/bin/env bash
#
# Pulse platform verification harness.
#
# One job: answer "is the platform in the state this module promised?" with an
# exit code. Every module adds a check group here, and no module is closed until
# its group passes.
#
# Usage:
#   ./platform/scripts/verify.sh            # run every registered group
#   ./platform/scripts/verify.sh nginx k8s  # run only these groups
#   VERBOSE=1 ./platform/scripts/verify.sh  # show the output of each check
#
# Exit codes: 0 all passed · 1 at least one failed · 2 bad usage

set -euo pipefail

PASS=0
FAIL=0
SKIP=0

readonly GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' DIM=$'\033[2m' RESET=$'\033[0m'

log()  { printf '%s\n' "$*" >&2; }
ok()   { PASS=$((PASS + 1)); log "  ${GREEN}PASS${RESET}  $1"; }
bad()  { FAIL=$((FAIL + 1)); log "  ${RED}FAIL${RESET}  $1"; [ -n "${2:-}" ] && log "        ${DIM}${2}${RESET}"; return 0; }
skip() { SKIP=$((SKIP + 1)); log "  ${YELLOW}SKIP${RESET}  $1 ${DIM}(${2:-not applicable yet})${RESET}"; }

# check <description> <command...>
# Runs the command; passes on exit 0. Captures output so a failure can explain
# itself instead of just saying "failed".
check() {
  local desc=$1; shift
  local out
  if out=$("$@" 2>&1); then
    ok "$desc"
    [ -n "${VERBOSE:-}" ] && [ -n "$out" ] && log "        ${DIM}${out}${RESET}"
  else
    bad "$desc" "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# --- group: tooling -----------------------------------------------------------
# Added in module 00. Proves the environment matches SETUP.md.
group_tooling() {
  log "${DIM}== tooling ==${RESET}"
  local t
  for t in docker kubectl kind helm shellcheck; do
    if have "$t"; then
      ok "$t is installed"
    else
      bad "$t is installed" "not found in PATH — see SETUP.md"
    fi
  done
  if have docker; then
    check "docker daemon reachable without sudo" docker info
  fi
}

# --- group: build -------------------------------------------------------------
# Added in module 01.
group_build() {
  log "${DIM}== build ==${RESET}"
  if ! have go; then
    skip "services compile" "go not installed"
    return
  fi
  local svc
  for svc in pulse-api pulse-worker; do
    check "$svc compiles" env -C "platform/services/$svc" go build -o /dev/null .
    check "$svc passes go vet" env -C "platform/services/$svc" go vet ./...
  done
}

# --- group: scripts -----------------------------------------------------------
# Added in module 01. The harness holds itself to its own standard.
group_scripts() {
  log "${DIM}== scripts ==${RESET}"
  if ! have shellcheck; then
    skip "shell scripts are clean" "shellcheck not installed"
    return
  fi
  local files=()
  while IFS= read -r -d '' f; do files+=("$f"); done \
    < <(find . -name '*.sh' -not -path './archive/*' -not -path './.git/*' -print0)
  if [ ${#files[@]} -eq 0 ]; then
    skip "shell scripts are clean" "no scripts yet"
    return
  fi
  check "shellcheck clean (${#files[@]} scripts)" shellcheck "${files[@]}"
}

# --- group: nginx -------------------------------------------------------------
# Added in module 02.
group_nginx() {
  log "${DIM}== nginx edge ==${RESET}"
  if ! have curl; then skip "edge responds" "curl not installed"; return; fi
  local base=${PULSE_EDGE_URL:-https://localhost:8443}
  check "edge serves the dashboard" curl -fsS -k -o /dev/null "$base/"
  check "edge proxies the API"      curl -fsS -k -o /dev/null "$base/api/checks"
  check "edge redirects HTTP to HTTPS" \
    bash -c "curl -fsS -o /dev/null -w '%{http_code}' '${base/https/http}' | grep -qE '^30[18]$'"
}

# --- group: k8s ---------------------------------------------------------------
# Added in module 04.
group_k8s() {
  log "${DIM}== kubernetes ==${RESET}"
  if ! have kubectl || ! kubectl cluster-info >/dev/null 2>&1; then
    skip "workloads are healthy" "no reachable cluster"
    return
  fi
  local ns=${PULSE_NAMESPACE:-pulse}
  check "namespace $ns exists" kubectl get namespace "$ns"
  check "all deployments available" \
    kubectl wait --for=condition=Available --timeout=60s deployment --all -n "$ns"
  check "no pod has restarted" bash -c "
    kubectl get pods -n '$ns' \
      -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' \
      | awk '{ t=0; for (i=1; i<=NF; i++) t+=\$i; if (t>0) { print \"total restarts: \" t; exit 1 } }'"
}

# --- group: gateway -----------------------------------------------------------
# Added in module 05. Replaces the nginx group once the edge is migrated.
group_gateway() {
  log "${DIM}== gateway api ==${RESET}"
  if ! have kubectl || ! kubectl cluster-info >/dev/null 2>&1; then
    skip "routes are attached" "no reachable cluster"
    return
  fi
  if ! kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
    skip "routes are attached" "Gateway API CRDs not installed"
    return
  fi

  local ns=${PULSE_NAMESPACE:-pulse}

  check "gateway is programmed" bash -c "
    kubectl get gateway -n '$ns' -o jsonpath='{.items[*].status.conditions[?(@.type==\"Programmed\")].status}' \
      | grep -qw True"

  # Both conditions must hold on every route. Accepted alone is not enough:
  # a route can attach to a listener and still fail to resolve its backends.
  check "every httproute is Accepted" bash -c "
    bad=\$(kubectl get httproute -n '$ns' -o jsonpath='{range .items[*]}{.metadata.name}={.status.parents[0].conditions[?(@.type==\"Accepted\")].status}{\"\n\"}{end}' \
      | grep -v '=True\$' || true)
    [ -z \"\$bad\" ] || { echo \"\$bad\"; exit 1; }"

  check "every httproute has ResolvedRefs" bash -c "
    bad=\$(kubectl get httproute -n '$ns' -o jsonpath='{range .items[*]}{.metadata.name}={.status.parents[0].conditions[?(@.type==\"ResolvedRefs\")].status}{\"\n\"}{end}' \
      | grep -v '=True\$' || true)
    [ -z \"\$bad\" ] || { echo \"\$bad\"; exit 1; }"
}

# --- group: storage -----------------------------------------------------------
# Added in module 06. A backup nobody has restored is a hypothesis, so this
# checks the drill ran recently rather than that files exist.
group_storage() {
  log "${DIM}== storage ==${RESET}"
  if ! have kubectl || ! kubectl cluster-info >/dev/null 2>&1; then
    skip "state is durable" "no reachable cluster"
    return
  fi
  local ns=${PULSE_NAMESPACE:-pulse}

  check "every PVC is Bound" bash -c "
    bad=\$(kubectl get pvc -n '$ns' -o jsonpath='{range .items[*]}{.metadata.name}={.status.phase}{\"\n\"}{end}' \
      | grep -v '=Bound\$' || true)
    [ -z \"\$bad\" ] || { echo \"\$bad\"; exit 1; }"

  check "postgres statefulset is ready" \
    kubectl rollout status statefulset/postgres -n "$ns" --timeout=30s

  # The check that matters: not "do backups exist" but "did a restore work".
  check "a restore was verified in the last 48h" bash -c "
    ts=\$(kubectl get configmap pulse-backup-state -n '$ns' \
      -o jsonpath='{.data.last_verified_epoch}' 2>/dev/null || echo 0)
    now=\$(date +%s)
    age=\$(( (now - \${ts:-0}) / 3600 ))
    [ \"\${ts:-0}\" -gt 0 ] || { echo 'no restore has ever been verified'; exit 1; }
    [ \"\$age\" -lt 48 ] || { echo \"last verified restore was \${age}h ago\"; exit 1; }"
}

# --- group: slo ---------------------------------------------------------------
# Added in module 07.
group_slo() {
  log "${DIM}== slo ==${RESET}"
  local prom=${PROMETHEUS_URL:-http://localhost:9090}
  if ! have curl || ! curl -fsS -o /dev/null --max-time 3 "$prom/-/ready" 2>/dev/null; then
    skip "SLO rules are loaded" "Prometheus not reachable at $prom"
    return
  fi

  check "pulse targets are up" bash -c "
    down=\$(curl -fsS '$prom/api/v1/query?query=up%7Bjob%3D~%22pulse.%2A%22%7D%3D%3D0' \
      | grep -o '\"metric\"' | wc -l)
    [ \"\$down\" -eq 0 ] || { echo \"\$down pulse target(s) down\"; exit 1; }"

  check "recording rules are evaluating" bash -c "
    curl -fsS '$prom/api/v1/query?query=pulse%3Ahttp_request_duration_seconds%3Arate5m' \
      | grep -q '\"result\":\[{'"

  # Guards against this module's break-fix.
  check "series count is under 500k" bash -c "
    n=\$(curl -fsS '$prom/api/v1/query?query=prometheus_tsdb_head_series' \
      | sed -n 's/.*\"value\":\[[0-9.]*,\"\([0-9]*\)\".*/\1/p')
    [ -n \"\$n\" ] || { echo 'could not read head series'; exit 1; }
    [ \"\$n\" -lt 500000 ] || { echo \"head series: \$n\"; exit 1; }"
}

# --- group: traces ------------------------------------------------------------
# Added in module 08.
group_traces() {
  log "${DIM}== traces ==${RESET}"
  local col=${OTELCOL_METRICS_URL:-http://localhost:8888}
  if ! have curl || ! curl -fsS -o /dev/null --max-time 3 "$col/metrics" 2>/dev/null; then
    skip "telemetry is flowing" "Collector metrics not reachable at $col"
    return
  fi

  check "collector is accepting spans" bash -c "
    curl -fsS '$col/metrics' | grep -q '^otelcol_receiver_accepted_spans'"

  # accepted minus sent, over time, is data you lost.
  check "collector is not refusing spans" bash -c "
    n=\$(curl -fsS '$col/metrics' | awk '/^otelcol_processor_refused_spans/ {s+=\$2} END {print s+0}')
    [ \"\$n\" -eq 0 ] || { echo \"refused spans: \$n — there is a hole in your data\"; exit 1; }"

  check "export queue has headroom" bash -c "
    size=\$(curl -fsS '$col/metrics' | awk '/^otelcol_exporter_queue_size/ {s+=\$2} END {print s+0}')
    cap=\$(curl -fsS '$col/metrics' | awk '/^otelcol_exporter_queue_capacity/ {s+=\$2} END {print s+0}')
    [ \"\$cap\" -gt 0 ] || { echo 'no queue capacity reported'; exit 1; }
    pct=\$(( size * 100 / cap ))
    [ \"\$pct\" -lt 80 ] || { echo \"queue at \${pct}%\"; exit 1; }"
}

# --- group: profiling ---------------------------------------------------------
# Added in module 08b. Everything here is obtained without modifying Pulse,
# which is the point of that module.
group_profiling() {
  log "${DIM}== profiling ==${RESET}"
  if ! have kubectl || ! kubectl cluster-info >/dev/null 2>&1; then
    skip "profiles are being collected" "no reachable cluster"
    return
  fi
  local ns=${PROFILING_NAMESPACE:-profiling}
  if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
    skip "profiles are being collected" "namespace $ns not found"
    return
  fi

  check "profiler is running" \
    kubectl wait --for=condition=Available --timeout=30s deployment --all -n "$ns"

  # The accept-queue counters from the module 08b break-fix. node-exporter has
  # exposed these all along; nobody looks at them until they already know.
  local prom=${PROMETHEUS_URL:-http://localhost:9090}
  if curl -fsS -o /dev/null --max-time 3 "$prom/-/ready" 2>/dev/null; then
    check "no TCP accept-queue overflows" bash -c "
      n=\$(curl -fsS '$prom/api/v1/query?query=increase(node_netstat_TcpExt_ListenOverflows%5B10m%5D)' \
        | grep -o '\"value\"' | wc -l)
      v=\$(curl -fsS '$prom/api/v1/query?query=sum(increase(node_netstat_TcpExt_ListenOverflows%5B10m%5D))' \
        | sed -n 's/.*\"value\":\[[0-9.]*,\"\([0-9.]*\)\".*/\1/p')
      [ -z \"\$v\" ] && { echo 'metric not present — is node-exporter scraped?'; exit 1; }
      awk -v x=\"\$v\" 'BEGIN { if (x+0 > 0) { print \"listen overflows in last 10m: \" x; exit 1 } }'"
  else
    skip "no TCP accept-queue overflows" "Prometheus not reachable"
  fi
}

# --- registry -----------------------------------------------------------------
# Order matters: cheap checks first so failures surface fast.
ALL_GROUPS=(tooling build scripts nginx gateway k8s storage slo traces profiling)

usage() {
  log "usage: $0 [group...]"
  log "groups: ${ALL_GROUPS[*]}"
  exit 2
}

main() {
  case "${1:-}" in
    -h|--help) usage ;;
  esac

  local groups=("$@")
  [ ${#groups[@]} -eq 0 ] && groups=("${ALL_GROUPS[@]}")

  local g
  for g in "${groups[@]}"; do
    # `--` is required: a group name starting with a dash would otherwise be
    # parsed by grep as an option.
    if ! printf '%s\n' "${ALL_GROUPS[@]}" | grep -qx -- "$g"; then
      log "unknown group: $g"
      usage
    fi
    "group_$g"
  done

  log ""
  log "${GREEN}${PASS} passed${RESET}  ${RED}${FAIL} failed${RESET}  ${YELLOW}${SKIP} skipped${RESET}"
  [ "$FAIL" -eq 0 ]
}

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
main "$@"
