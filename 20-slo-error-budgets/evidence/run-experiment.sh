#!/usr/bin/env bash
# Full error-budget burn experiment, capturing evidence at every phase.
#
# Timeline:
#   1. record the healthy baseline
#   2. inject a 35% error rate
#   3. poll until SLODemoAvailabilityFastBurn reaches FIRING
#   4. heal the service
#   5. poll until the alert clears, showing the short window doing its job
#
# Run from the module root:  ./evidence/run-experiment.sh
set -euo pipefail

cd "$(dirname "$0")/.."
CHAOS=./loadgen/chaos.sh
OUT=./evidence
ERROR_RATE=${ERROR_RATE:-0.35}

ts() { date -u '+%H:%M:%SZ'; }
say() { printf '\n\033[1;36m[%s] %s\033[0m\n' "$(ts)" "$*"; }

# ---------------------------------------------------------------- phase 1
say "Phase 1 — healthy baseline"
{
  echo "PHASE 1 — BASELINE (no chaos injected)"
  echo
  $CHAOS status
  echo
  $CHAOS alerts
} | tee "$OUT/01-baseline-healthy.txt"

# ---------------------------------------------------------------- phase 2
say "Phase 2 — injecting ${ERROR_RATE} error rate"
{
  echo "PHASE 2 — CHAOS INJECTED (error_rate=${ERROR_RATE})"
  echo
  $CHAOS break "$ERROR_RATE"
} | tee "$OUT/02-chaos-injected.txt"

# ---------------------------------------------------------------- phase 3
# The 5m window crosses 7.2% within ~2 minutes, but the alert also requires the
# 1h window to cross it, and the 1h window is still diluted by healthy traffic.
# That delay is the whole point of the long window: it refuses to page until the
# burn is actually significant.
say "Phase 3 — waiting for SLODemoAvailabilityFastBurn to fire"
: > "$OUT/03-burn-progression.txt"
FIRED=0
for i in $(seq 1 30); do
  {
    echo "----- poll #$i -----"
    $CHAOS status
    echo
    $CHAOS alerts
    echo
  } | tee -a "$OUT/03-burn-progression.txt"

  STATE=$($CHAOS alerts | grep -o 'FIRING\] SLODemoAvailabilityFastBurn' || true)
  if [[ -n "$STATE" ]]; then
    say "FastBurn alert is FIRING (poll #$i)"
    { echo "PHASE 3 — ALERT FIRING"; echo; $CHAOS status; echo; $CHAOS alerts; } \
      | tee "$OUT/04-alert-firing.txt"
    FIRED=1
    break
  fi
  sleep 45
done

if [[ "$FIRED" -eq 0 ]]; then
  echo "WARNING: alert did not reach FIRING within the polling budget" | tee -a "$OUT/03-burn-progression.txt"
fi

# ---------------------------------------------------------------- phase 4
say "Phase 4 — healing the service"
{
  echo "PHASE 4 — HEALED (error_rate back to 0.001)"
  echo
  $CHAOS heal
} | tee "$OUT/05-healed.txt"

# ---------------------------------------------------------------- phase 5
say "Phase 5 — watching the alert resolve"
: > "$OUT/06-recovery.txt"
for i in $(seq 1 12); do
  {
    echo "----- recovery poll #$i -----"
    $CHAOS status
    echo
    $CHAOS alerts
    echo
  } | tee -a "$OUT/06-recovery.txt"

  if $CHAOS alerts | grep -q 'none — all SLO alerts inactive'; then
    say "All SLO alerts back to inactive (poll #$i)"
    break
  fi
  sleep 45
done

say "Done. Evidence written to $OUT/"
ls -la "$OUT"
