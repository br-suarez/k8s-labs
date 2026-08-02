#!/usr/bin/env bash
# Terraform: build a module, import an object created outside Terraform, then
# cause drift two different ways and resolve each one differently.
set -uo pipefail

cd "$(dirname "$0")"
NS=tf-lab
OUT=./evidence
mkdir -p "$OUT"

run() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
hdr() { printf '\n========== %s ==========\n' "$*"; }

# Clean slate so the run is reproducible.
kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1
rm -rf .terraform terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl

{
echo "======================================================================"
echo " TERRAFORM — module, import, drift"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

hdr "init / validate / fmt"
run terraform init -no-color
run terraform validate -no-color
run terraform fmt -check -recursive -no-color

hdr "APPLY 1 — everything except the resource to be imported"
echo "
kubernetes_config_map_v1.legacy_settings is written in main.tf but the object
does not exist yet, so it is excluded from this apply with -target. Using
-target here is legitimate: the point is to reach a state where that ONE
resource is configured-but-not-in-state, which is the situation import solves."
run terraform apply -auto-approve -no-color \
  -target=kubernetes_namespace_v1.lab -target=module.checkout

run kubectl get all,cm -n "$NS"
run terraform output -no-color

# ==================================================================== IMPORT
hdr "IMPORT — an object created outside Terraform"
echo "
Simulating the usual reality: something was created by hand, long ago, by
somebody else. Terraform did not create it and does not know it exists."
run kubectl create configmap legacy-settings -n "$NS" \
  --from-literal=owner=payments-team \
  --from-literal=tier=internal \
  --from-literal=log_level=info

echo "
Terraform's view: it wants to CREATE the object, which would fail because the
object already exists."
run sh -c "terraform plan -no-color | tail -25"

echo "
Import binds the live object to the configuration block:"
run terraform import -no-color kubernetes_config_map_v1.legacy_settings "${NS}/legacy-settings"

echo "
Now the plan is clean — configuration and reality agree:"
run sh -c "terraform plan -no-color | tail -8"

run sh -c "terraform state list"

# ================================================================ DRIFT 1
hdr "DRIFT 1 — someone scales the Deployment by hand"
echo "
The classic 3am fix: scale up during an incident, forget to update the code."
run kubectl scale deployment checkout -n "$NS" --replicas=5
sleep 6
run kubectl get deployment checkout -n "$NS" -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas'

echo "
'terraform plan -refresh-only' shows drift WITHOUT proposing to change anything.
This is the read-only way to answer 'what has changed underneath us?'"
# `tail` is the wrong filter here: refresh-only output ends with boilerplate
# and provider normalisation noise, so the actual drift scrolls off the top.
# Print the block Terraform dedicates to out-of-band changes instead.
run sh -c "terraform plan -refresh-only -no-color | sed -n '/changed outside of Terraform/,/This is a refresh-only plan/p' | head -75"

echo "
A normal plan proposes to correct it back to what the code says:"
run sh -c "terraform plan -no-color | tail -20"

echo "
Applying reconciles reality to the code — the manual scale is reverted:"
run terraform apply -auto-approve -no-color
run kubectl get deployment checkout -n "$NS" -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas'

# ================================================================ DRIFT 2
hdr "DRIFT 2 — someone edits a ConfigMap Terraform owns"
run kubectl patch configmap legacy-settings -n "$NS" \
  --type merge -p '{"data":{"log_level":"debug","added_by_hand":"true"}}'
run kubectl get cm legacy-settings -n "$NS" -o jsonpath='{.data}{"\n"}'

echo "
Drift detected on two keys — one changed, one added:"
# `tail` is the wrong filter here: refresh-only output ends with boilerplate
# and provider normalisation noise, so the actual drift scrolls off the top.
# Print the block Terraform dedicates to out-of-band changes instead.
run sh -c "terraform plan -refresh-only -no-color | sed -n '/changed outside of Terraform/,/This is a refresh-only plan/p' | head -75"

echo "
Here the choice matters. Two valid, opposite responses:

  terraform apply              -> code wins. Revert the manual change.
  terraform apply -refresh-only -> reality wins. Accept it into state,
                                   leaving the CODE now out of date.

The second is the trap: it makes the plan clean without making the
configuration correct. Choosing it means committing to update the code next.
This run takes the first option."
run terraform apply -auto-approve -no-color
run kubectl get cm legacy-settings -n "$NS" -o jsonpath='{.data}{"\n"}'

echo "
Final plan — no changes:"
run sh -c "terraform plan -no-color | tail -6"
} | tee "$OUT/01-import-and-drift.txt"

echo
echo "Evidence written to ${OUT}/"
