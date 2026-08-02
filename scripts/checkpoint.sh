#!/usr/bin/env bash
#
# Platform checkpoints.
#
# The capstone accumulates, which is what makes it valuable and also what makes
# it a single point of failure: a platform left half-migrated at module 09 can
# block module 10 for reasons that have nothing to do with learning module 10.
#
# This is the mitigation. At the end of every module you tag a known-good state.
# If a later module gets stuck on platform debt rather than on the material, you
# are one command away from a baseline that worked.
#
# It does NOT let you skip a module — the tag only exists once you closed that
# module properly. It just stops an environment problem from becoming a
# curriculum problem.
#
# Usage:
#   ./scripts/checkpoint.sh save 05          # tag the current state
#   ./scripts/checkpoint.sh list
#   ./scripts/checkpoint.sh diff 05          # what changed since
#   ./scripts/checkpoint.sh restore 05       # branch off that state
#   ./scripts/checkpoint.sh rebuild 05       # cluster from scratch to that state

set -euo pipefail

readonly PREFIX="checkpoint/mod-"
readonly GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' DIM=$'\033[2m' RESET=$'\033[0m'

log() { printf '%s\n' "$*" >&2; }
die() { log "${RED}error:${RESET} $*"; exit 1; }

cd "$(dirname "${BASH_SOURCE[0]}")/.."

git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"

tag_for() { printf '%s%s' "$PREFIX" "$1"; }

cmd_save() {
  local mod=${1:-} tag
  [ -n "$mod" ] || die "usage: $0 save <module>   e.g. 05, 08b"
  tag=$(tag_for "$mod")

  git diff --quiet && git diff --cached --quiet \
    || die "working tree is dirty — commit your module before checkpointing"

  git rev-parse -q --verify "refs/tags/$tag" >/dev/null \
    && die "$tag already exists. Delete it first if you really mean to move it."

  # Record what the platform looked like, not just the code. When you come back
  # in three months, "which images and which cluster profile" is the question
  # you will actually need answered.
  local meta="modules-complete: $mod
date: $(date -Is)
kind-clusters: $(kind get clusters 2>/dev/null | tr '\n' ' ' || echo 'none')
images: $(docker images --filter reference='pulse-*' --format '{{.Repository}}:{{.Tag}}@{{.ID}}' 2>/dev/null | tr '\n' ' ' || echo 'none')"

  git tag -a "$tag" -m "Checkpoint after module $mod

$meta"

  log "${GREEN}saved${RESET} $tag"
  log "${DIM}$meta${RESET}"
}

cmd_list() {
  local tags
  tags=$(git tag -l "${PREFIX}*" --sort=version:refname)
  [ -n "$tags" ] || { log "${YELLOW}no checkpoints yet${RESET}"; return; }

  printf '%-22s %-12s %s\n' "TAG" "DATE" "SUBJECT" >&2
  local t
  while IFS= read -r t; do
    printf '%-22s %-12s %s\n' \
      "$t" \
      "$(git log -1 --format=%ad --date=short "$t")" \
      "$(git log -1 --format=%s "$t")" >&2
  done <<< "$tags"
}

cmd_diff() {
  local mod=${1:-} tag
  [ -n "$mod" ] || die "usage: $0 diff <module>"
  tag=$(tag_for "$mod")
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "$tag does not exist"

  log "${DIM}changes since $tag:${RESET}"
  git diff --stat "$tag"..HEAD
}

cmd_restore() {
  local mod=${1:-} tag branch
  [ -n "$mod" ] || die "usage: $0 restore <module>"
  tag=$(tag_for "$mod")
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "$tag does not exist"

  branch="recover/from-mod-$mod-$(date +%Y%m%d-%H%M)"

  git diff --quiet && git diff --cached --quiet \
    || die "working tree is dirty — commit or stash first. Nothing was changed."

  # A branch, never a detached checkout of the working tree: recovering from a
  # bad state should not be able to destroy the work that got you there.
  git checkout -b "$branch" "$tag"

  log ""
  log "${GREEN}on branch $branch${RESET}, at the state after module $mod."
  log ""
  log "Your later work is untouched on its own branch."
  log "Rebuild the cluster to match with:"
  log "  ${DIM}$0 rebuild $mod${RESET}"
}

cmd_rebuild() {
  local mod=${1:-}
  [ -n "$mod" ] || die "usage: $0 rebuild <module>"

  log "${YELLOW}This deletes the current kind cluster and rebuilds it.${RESET}"
  log "Applying the platform as of module $mod."
  log ""

  local profile=standard
  case "$mod" in
    0[0-6]|0[0-6]*) profile=lite ;;
  esac

  kind delete cluster --name pulse 2>/dev/null || true
  kind delete cluster --name pulse-lite 2>/dev/null || true
  kind create cluster --config "platform/deploy/clusters/${profile}.yaml"

  if [ -d platform/deploy/k8s ]; then
    kubectl apply -f platform/deploy/k8s/
  else
    log "${YELLOW}no platform/deploy/k8s yet — nothing to apply${RESET}"
  fi

  log ""
  log "Verify with: ./platform/scripts/verify.sh"
}

case "${1:-}" in
  save)    shift; cmd_save "$@" ;;
  list)    cmd_list ;;
  diff)    shift; cmd_diff "$@" ;;
  restore) shift; cmd_restore "$@" ;;
  rebuild) shift; cmd_rebuild "$@" ;;
  *)
    log "usage: $0 {save <mod> | list | diff <mod> | restore <mod> | rebuild <mod>}"
    exit 2 ;;
esac
