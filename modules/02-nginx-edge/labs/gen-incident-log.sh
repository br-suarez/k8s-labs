#!/usr/bin/env bash
#
# Generate the access log analysed in lab 02.04.
#
# There is a real incident buried in here. Do not read this script before doing
# the lab — generate the log, analyse it, and only then come back and check
# whether your diagnosis matches what was actually generated.

set -euo pipefail

OUT=${1:-access.log}
: > "$OUT"

# Log format being emulated:
# $remote_addr - - [$time_local] "$request" $status $body_bytes_sent
#   rt=$request_time uct=$upstream_connect_time urt=$upstream_response_time
#   ucs=$upstream_cache_status

emit() {
  local ts=$1 ip=$2 req=$3 status=$4 bytes=$5 rt=$6 uct=$7 urt=$8 ucs=$9
  printf '%s - - [%s] "%s" %s %s rt=%s uct=%s urt=%s ucs=%s\n' \
    "$ip" "$ts" "$req" "$status" "$bytes" "$rt" "$uct" "$urt" "$ucs" >> "$OUT"
}

rand_ip() { printf '203.0.113.%d' $((RANDOM % 200 + 1)); }

# Deterministic-ish pseudo random in a range, 3 decimals
rnd() { awk -v a="$1" -v b="$2" -v s="$RANDOM" 'BEGIN{srand(s);printf "%.3f", a+(b-a)*rand()}'; }

ts_at() {
  # $1 = minutes past 14:00
  date -u -d "2026-07-28 14:00:00 UTC +$1 minutes" '+%d/%b/%Y:%H:%M:%S +0000'
}

# --- 14:00-14:20 — healthy baseline ------------------------------------------
for m in $(seq 0 19); do
  for _ in $(seq 12); do
    emit "$(ts_at "$m")" "$(rand_ip)" "GET /api/results HTTP/1.1" 200 4210 \
      "$(rnd 0.010 0.080)" "$(rnd 0.001 0.003)" "$(rnd 0.008 0.070)" HIT
  done
  for _ in $(seq 4); do
    emit "$(ts_at "$m")" "$(rand_ip)" "GET / HTTP/1.1" 200 1840 \
      "$(rnd 0.005 0.020)" "-" "-" "-"
  done
  emit "$(ts_at "$m")" "$(rand_ip)" "POST /api/checks HTTP/1.1" 201 210 \
    "$(rnd 0.020 0.060)" "$(rnd 0.001 0.003)" "$(rnd 0.018 0.055)" "-"
done

# --- 14:20-14:35 — the incident ----------------------------------------------
# Client-side degradation: request_time climbs, upstream_response_time does not.
# A single subnet is responsible. The backend is fine throughout.
for m in $(seq 20 34); do
  for _ in $(seq 10); do
    emit "$(ts_at "$m")" "$(rand_ip)" "GET /api/results HTTP/1.1" 200 4210 \
      "$(rnd 0.010 0.080)" "$(rnd 0.001 0.003)" "$(rnd 0.008 0.070)" HIT
  done
  # The slow cohort — all from 198.51.100.0/24, all large downloads
  for _ in $(seq 14); do
    emit "$(ts_at "$m")" "198.51.100.$((RANDOM % 40 + 1))" \
      "GET /api/results?limit=10000 HTTP/1.1" 200 8420000 \
      "$(rnd 8.000 45.000)" "$(rnd 0.001 0.004)" "$(rnd 0.090 0.180)" MISS
  done
  # A few genuine 499s: clients giving up mid-download
  for _ in $(seq 3); do
    emit "$(ts_at "$m")" "198.51.100.$((RANDOM % 40 + 1))" \
      "GET /api/results?limit=10000 HTTP/1.1" 499 0 \
      "$(rnd 30.000 60.000)" "$(rnd 0.001 0.004)" "$(rnd 0.090 0.200)" MISS
  done
done

# --- 14:35-14:50 — recovery ---------------------------------------------------
for m in $(seq 35 49); do
  for _ in $(seq 12); do
    emit "$(ts_at "$m")" "$(rand_ip)" "GET /api/results HTTP/1.1" 200 4210 \
      "$(rnd 0.010 0.080)" "$(rnd 0.001 0.003)" "$(rnd 0.008 0.070)" HIT
  done
  for _ in $(seq 4); do
    emit "$(ts_at "$m")" "$(rand_ip)" "GET / HTTP/1.1" 200 1840 \
      "$(rnd 0.005 0.020)" "-" "-" "-"
  done
done

sort -t'[' -k2 -o "$OUT" "$OUT"
echo "wrote $(wc -l < "$OUT") lines to $OUT" >&2
