#!/usr/bin/env bash
# Build the three releases this lab rolls out, and load them into kind.
#
#   slo-demo:v1        current production — 0.1% errors, inside the SLO
#   slo-demo:v2-bad    a release that regressed — 20% errors, blows the budget
#   slo-demo:v3-fixed  the fix — back inside the SLO
#
# v2/v3 are built FROM v1 and only set environment variables. That keeps the
# binary byte-identical across all three, so when the canary analysis rejects
# v2-bad there is no ambiguity about what caused it: the only difference is the
# configuration the image carries. A config regression is also the more common
# real-world outage, which makes it the honest thing to demo.
set -euo pipefail

cd "$(dirname "$0")"
BASE_APP=../../20-slo-error-budgets/app
CLUSTER=${CLUSTER:-slo-lab}

echo "==> Rebuilding base image slo-demo:v1 (now reads env config)"
docker build -q -t slo-demo:v1 "$BASE_APP" >/dev/null
echo "    ok"

for tag in v2-bad v3-fixed; do
  echo "==> Building slo-demo:${tag}"
  docker build -q -t "slo-demo:${tag}" -f "Dockerfile.${tag}" . >/dev/null
  echo "    ok"
done

echo "==> Loading into kind cluster '${CLUSTER}'"
kind load docker-image slo-demo:v1 slo-demo:v2-bad slo-demo:v3-fixed --name "$CLUSTER" 2>&1 | sed 's/^/    /'

echo
# `docker images ... | grep` under `set -o pipefail` makes the whole script exit
# non-zero whenever grep matches nothing, so filter with docker itself instead.
docker images slo-demo --format '    {{.Repository}}:{{.Tag}}  {{.Size}}' | sort
