#!/usr/bin/env bash
# Chart lifecycle: install -> upgrade -> break -> rollback -> verify,
# plus what --atomic changes about all of it.
set -uo pipefail

cd "$(dirname "$0")"
NS=helm-lab
REL=checkout
CHART=./checkout-api
OUT=./evidence
mkdir -p "$OUT"

run() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
hdr() { printf '\n========== %s ==========\n' "$*"; }

# Query the app through the Service to prove what is actually SERVING, rather
# than trusting what the manifests claim.
probe() {
  kubectl run "probe-$RANDOM" -n "$NS" --rm -i --restart=Never --quiet \
    --image=curlimages/curl:8.10.1 --timeout=60s -- \
    curl -s -m 5 "http://${REL}-checkout-api:8080/api" 2>/dev/null | head -1
}

kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1
kubectl create namespace "$NS" >/dev/null

{
echo "======================================================================"
echo " HELM — package, upgrade, rollback"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

hdr "Lint and render before touching the cluster"
run helm lint "$CHART"
echo "
'helm template' renders locally with no cluster involved. It is the fastest way
to catch a templating mistake, and it is what should run in CI."
run sh -c "helm template $REL $CHART --namespace $NS | head -30"

hdr "REVISION 1 — install"
run helm install "$REL" "$CHART" --namespace "$NS" --wait --timeout 3m
run kubectl get pods,cm,svc -n "$NS"
echo "
What the service actually returns:"
probe; echo

hdr "REVISION 2 — upgrade a value (replicas 2->3, version v1->v2, config change)"
run helm upgrade "$REL" "$CHART" --namespace "$NS" \
  --set replicaCount=3 \
  --set appVersion=v2 \
  --set config.greeting="checkout-api v2" \
  --set config.featureFlags="checkout_v2=on" \
  --wait --timeout 3m

run kubectl get pods -n "$NS" -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image,VERSION:.spec.containers[0].env[0].value'
run kubectl get cm -n "$NS" "${REL}-checkout-api" -o jsonpath='{.data}{"\n"}'
echo "
Serving:"
probe; echo

hdr "REVISION 3 — a broken upgrade that Helm calls a success"
echo "
Upgrading to an image tag that does not exist. Note there is no --wait here,
which is how most upgrade commands are actually written."
run helm upgrade "$REL" "$CHART" --namespace "$NS" \
  --set replicaCount=3 \
  --set appVersion=v3-broken \
  --set image.tag=v9-does-not-exist \
  --set config.greeting="checkout-api v3" \
  --set config.featureFlags="checkout_v2=on"

echo "
Helm reports the release as deployed. (--output json also embeds the whole
rendered manifest, so filter to .info or the answer is buried in 3 KB of YAML.)"
run sh -c "helm status $REL -n $NS --output json | jq '.info | {status, description, last_deployed}'"
echo
sleep 25
echo "The cluster disagrees:"
run kubectl get pods -n "$NS" -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATE:.status.containerStatuses[0].state.waiting.reason,IMAGE:.spec.containers[0].image'

echo "
Old pods are still serving because a Deployment will not tear down healthy
replicas for a rollout that never becomes Ready — this is a partial outage,
not a total one, which is exactly why it is easy to miss:"
probe; echo

hdr "helm history — what is available to roll back to"
echo "
Watch the APP VERSION column: it reads v1 on every row, because it comes from
Chart.yaml's appVersion — NOT from the .Values.appVersion overridden with --set.
The history gives no hint that revision 3 shipped a different image."
run helm history "$REL" -n "$NS"

hdr "ROLLBACK to revision 2"
run helm rollback "$REL" 2 --namespace "$NS" --wait --timeout 3m

echo "
Deployment state after rollback:"
run kubectl get pods -n "$NS" -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,IMAGE:.spec.containers[0].image,VERSION:.spec.containers[0].env[0].value'

echo "
The ConfigMap — a second, independent object — reverted too:"
run kubectl get cm -n "$NS" "${REL}-checkout-api" -o jsonpath='{.data}{"\n"}'

echo "
Serving:"
probe; echo

hdr "helm history after the rollback"
echo "
Note the rollback did not RESTORE revision 2; it created revision 4 whose
content equals revision 2. Helm history is append-only, so 'roll back to the
last good one' means finding it, not decrementing a number."
run helm history "$REL" -n "$NS"

hdr "--atomic — the flag that would have prevented revision 3"
echo "
Same broken upgrade, this time with --atomic. Helm waits for readiness and
rolls back automatically when it does not arrive."
run helm upgrade "$REL" "$CHART" --namespace "$NS" \
  --set replicaCount=3 \
  --set appVersion=v5-broken \
  --set image.tag=v9-does-not-exist \
  --atomic --timeout 90s

echo "
State after the failed atomic upgrade — still the good version:"
run kubectl get pods -n "$NS" -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,IMAGE:.spec.containers[0].image,VERSION:.spec.containers[0].env[0].value'
probe; echo
run helm history "$REL" -n "$NS"

hdr "Packaging"
run helm package "$CHART" --destination /tmp
run sh -c "ls -la /tmp/checkout-api-*.tgz"
} | tee "$OUT/01-lifecycle.txt"

echo
echo "Evidence written to ${OUT}/"
