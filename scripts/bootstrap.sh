#!/usr/bin/env bash
#
# Install the pinned toolchain for this track on Ubuntu 24.04 (WSL2).
#
# Idempotent: safe to re-run. It reports what it changed and skips what is
# already at the pinned version.
#
# Read this before you run it. Module 00 asks you to, and the reason is that a
# bootstrap script you did not read is exactly the kind of magic that leaves you
# unable to debug your own environment three modules later.
#
# Usage:
#   ./scripts/bootstrap.sh              # install everything missing
#   ./scripts/bootstrap.sh --dry-run    # show what would change
#   ./scripts/bootstrap.sh kind kubectl # only these

set -euo pipefail

# --- pinned versions ----------------------------------------------------------
# Keep in sync with the table in SETUP.md. Verified 2026-08-02.
readonly KIND_VERSION="v0.32.0"
readonly KUBECTL_VERSION="v1.36.1"
readonly HELM_VERSION="v4.2.3"
readonly TERRAFORM_VERSION="1.15.8"
readonly TRIVY_VERSION="v0.72.0"
readonly COSIGN_VERSION="v3.1.2"

readonly BIN_DIR="/usr/local/bin"
DRY_RUN=""

readonly GREEN=$'\033[32m' YELLOW=$'\033[33m' RED=$'\033[31m' DIM=$'\033[2m' RESET=$'\033[0m'
log()     { printf '%s\n' "$*" >&2; }
info()    { log "${DIM}···${RESET} $*"; }
changed() { log "${GREEN} + ${RESET} $*"; }
present() { log "${DIM} = ${RESET} $* ${DIM}(already current)${RESET}"; }
warn()    { log "${YELLOW} ! ${RESET} $*"; }
die()     { log "${RED}error:${RESET} $*"; exit 1; }

run() {
  if [ -n "$DRY_RUN" ]; then
    log "${DIM}would run:${RESET} $*"
    return 0
  fi
  "$@"
}

arch() {
  case "$(uname -m)" in
    x86_64)  echo amd64 ;;
    aarch64) echo arm64 ;;
    *)       die "unsupported architecture: $(uname -m)" ;;
  esac
}

# installed_version <cmd> <version-flag-output-filter>
have() { command -v "$1" >/dev/null 2>&1; }

# fetch_binary <url> <destination-name>
fetch_binary() {
  local url=$1 name=$2 tmp
  tmp=$(mktemp)
  run curl -fsSL -o "$tmp" "$url" || die "download failed: $url"
  run chmod +x "$tmp"
  run sudo mv "$tmp" "$BIN_DIR/$name"
}

# --- components ---------------------------------------------------------------

install_apt() {
  info "refreshing apt metadata"
  run sudo apt-get update -qq
  local pkgs=(curl ca-certificates git jq shellcheck make gnupg)
  local missing=()
  local p
  for p in "${pkgs[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if [ ${#missing[@]} -eq 0 ]; then
    present "apt packages: ${pkgs[*]}"
  else
    run sudo apt-get install -y "${missing[@]}"
    changed "apt packages: ${missing[*]}"
  fi
}

install_docker() {
  if have docker; then
    present "docker $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ,)"
  else
    info "installing docker engine (not Docker Desktop — see SETUP.md)"
    run bash -c 'curl -fsSL https://get.docker.com | sudo sh'
    run sudo usermod -aG docker "$USER"
    changed "docker engine"
    warn "log out and back into WSL, or run 'newgrp docker', before using docker"
  fi
}

install_kind() {
  if have kind && [ "v$(kind version -q 2>/dev/null)" = "$KIND_VERSION" ]; then
    present "kind $KIND_VERSION"
    return
  fi
  fetch_binary "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-$(arch)" kind
  changed "kind $KIND_VERSION"
}

install_kubectl() {
  if have kubectl && kubectl version --client -o json 2>/dev/null \
      | grep -q "\"gitVersion\": \"$KUBECTL_VERSION\""; then
    present "kubectl $KUBECTL_VERSION"
    return
  fi
  fetch_binary \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/$(arch)/kubectl" kubectl
  changed "kubectl $KUBECTL_VERSION"
}

install_helm() {
  if have helm && helm version --short 2>/dev/null | grep -q "^${HELM_VERSION}"; then
    present "helm $HELM_VERSION"
    return
  fi
  local tmp
  tmp=$(mktemp -d)
  run curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-$(arch).tar.gz" \
    -o "$tmp/helm.tgz"
  run tar -xzf "$tmp/helm.tgz" -C "$tmp"
  run sudo mv "$tmp/linux-$(arch)/helm" "$BIN_DIR/helm"
  run rm -rf "$tmp"
  changed "helm $HELM_VERSION"
}

install_terraform() {
  if have terraform && terraform version -json 2>/dev/null \
      | grep -q "\"terraform_version\":\"$TERRAFORM_VERSION\""; then
    present "terraform $TERRAFORM_VERSION"
    return
  fi
  local tmp
  tmp=$(mktemp -d)
  run curl -fsSL \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_$(arch).zip" \
    -o "$tmp/tf.zip"
  run unzip -qo "$tmp/tf.zip" -d "$tmp"
  run sudo mv "$tmp/terraform" "$BIN_DIR/terraform"
  run rm -rf "$tmp"
  changed "terraform $TERRAFORM_VERSION"
}

install_trivy() {
  if have trivy && trivy --version 2>/dev/null | grep -q "${TRIVY_VERSION#v}"; then
    present "trivy $TRIVY_VERSION"
    return
  fi
  local tmp
  tmp=$(mktemp -d)
  local a; a=$(arch)
  [ "$a" = amd64 ] && a=64bit
  [ "$a" = arm64 ] && a=ARM64
  run curl -fsSL \
    "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION#v}_Linux-${a}.tar.gz" \
    -o "$tmp/trivy.tgz"
  run tar -xzf "$tmp/trivy.tgz" -C "$tmp"
  run sudo mv "$tmp/trivy" "$BIN_DIR/trivy"
  run rm -rf "$tmp"
  changed "trivy $TRIVY_VERSION"
}

install_cosign() {
  if have cosign && cosign version 2>/dev/null | grep -q "${COSIGN_VERSION#v}"; then
    present "cosign $COSIGN_VERSION"
    return
  fi
  fetch_binary \
    "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-$(arch)" \
    cosign
  changed "cosign $COSIGN_VERSION"
}

install_shell_helpers() {
  local rc="$HOME/.bashrc"
  if grep -q 'start_kubectl k' "$rc" 2>/dev/null; then
    present "kubectl completion and alias"
    return
  fi
  if [ -n "$DRY_RUN" ]; then
    log "${DIM}would append kubectl completion to $rc${RESET}"
    return
  fi
  {
    echo ''
    echo '# added by devops-sre-mastery bootstrap'
    echo 'source <(kubectl completion bash)'
    echo 'alias k=kubectl'
    echo 'complete -o default -F __start_kubectl k'
  } >> "$rc"
  changed "kubectl completion and alias (restart your shell)"
}

# --- main ---------------------------------------------------------------------

ALL=(apt docker kind kubectl helm terraform trivy cosign shell_helpers)

main() {
  local requested=()
  local a
  for a in "$@"; do
    case "$a" in
      --dry-run) DRY_RUN=1 ;;
      -h|--help)
        log "usage: $0 [--dry-run] [component...]"
        log "components: ${ALL[*]}"
        exit 0 ;;
      *) requested+=("$a") ;;
    esac
  done
  [ ${#requested[@]} -eq 0 ] && requested=("${ALL[@]}")

  [ -n "$DRY_RUN" ] && warn "dry run — nothing will be changed"

  grep -qi microsoft /proc/version 2>/dev/null \
    || warn "this does not look like WSL; SETUP.md assumes Ubuntu 24.04 on WSL2"

  local c
  for c in "${requested[@]}"; do
    if ! printf '%s\n' "${ALL[@]}" | grep -qx "$c"; then
      die "unknown component: $c (known: ${ALL[*]})"
    fi
    "install_$c"
  done

  log ""
  log "done. verify with: ./scripts/verify-setup.sh"
}

main "$@"
