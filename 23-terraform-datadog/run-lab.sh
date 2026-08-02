#!/usr/bin/env bash
# fmt, validate and PLAN the Datadog configuration without a Datadog account.
#
# There is no `apply` here and the README says so plainly. What this proves is
# that the configuration is syntactically valid, internally consistent, and
# produces the exact set of resources intended — which is what a pull request
# reviewer needs and what CI would run on every commit.
set -uo pipefail

cd "$(dirname "$0")"
OUT=./evidence
mkdir -p "$OUT"

run() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
hdr() { printf '\n========== %s ==========\n' "$*"; }

rm -rf .terraform terraform.tfstate* .terraform.lock.hcl tfplan

# Offline planning. In a real environment these come from the CI secret store
# and datadog_validate stays at its default of true.
export TF_VAR_datadog_validate=false
export TF_VAR_datadog_api_key="PLAN_ONLY_PLACEHOLDER"
export TF_VAR_datadog_app_key="PLAN_ONLY_PLACEHOLDER"

{
echo "======================================================================"
echo " TERRAFORM + DATADOG — validate and plan (no apply, no account)"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

hdr "init"
run terraform init -no-color

hdr "fmt — formatting is not a review conversation"
run terraform fmt -check -recursive -no-color

hdr "validate — types, references, required arguments"
run terraform validate -no-color

hdr "plan — the full set of resources this would create"
run sh -c "terraform plan -no-color -out=tfplan 2>&1 | tail -40"

hdr "the plan as a machine-readable summary"
echo "
'terraform show -json' is what a policy check (OPA, Conftest, Sentinel) reads.
Reviewing a plan by eye does not scale; asserting on its JSON does."
run sh -c "terraform show -json tfplan | jq -r '
  .resource_changes[]
  | \"  \(.change.actions[0] | ascii_upcase)  \(.type)  \(.name)\"' | sort"

hdr "what a plan CANNOT tell you"
echo "
Attempting to print each monitor's final query fails: it is null in the plan.

Every burn-rate query interpolates the SLO's id —
  burn_rate(\"\${datadog_service_level_objective.availability.id}\")...
— and that id does not exist until the SLO is created. Terraform therefore
marks the whole attribute unknown, and 'after' carries null rather than a
string.

The consequence matters for policy gates: a check that asserts on a monitor's
QUERY cannot run at plan time here, because the value genuinely is not knowable
yet. Checks must target attributes that are fully determined by the
configuration — tags, priority, renotify_interval, message — or move to a
post-apply test."
run sh -c "terraform show -json tfplan | jq -r '
  .resource_changes[]
  | select(.type == \"datadog_monitor\")
  | \"  \(.name)\",
    \"      query in .after         : \(.change.after.query // \"null (unknown at plan time)\")\",
    \"      query in .after_unknown : \(.change.after_unknown.query)\",
    \"      priority (known)        : \(.change.after.priority)\"'"

hdr "what a policy gate could assert on this plan"
echo "
Example checks a CI job would run against the JSON above, without any Datadog
credentials at all:"
run sh -c "terraform show -json tfplan | jq -r '
  [.resource_changes[] | select(.type==\"datadog_monitor\")] as \$m
  | \"  monitors planned:            \(\$m | length)\",
    \"  every monitor tagged:        \(if (\$m | all(.change.after.tags | index(\"managed-by:terraform\"))) then \"PASS\" else \"FAIL\" end)\",
    \"  every monitor has a message: \(if (\$m | all(.change.after.message | length > 0)) then \"PASS\" else \"FAIL\" end)\",
    \"  page-severity have renotify: \(if (\$m | map(select(.change.after.priority <= 2)) | all(.change.after.renotify_interval > 0)) then \"PASS\" else \"FAIL\" end)\"'"
} | tee "$OUT/01-validate-and-plan.txt"

rm -f tfplan
echo
echo "Evidence written to ${OUT}/"
