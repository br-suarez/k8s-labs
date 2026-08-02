#!/usr/bin/env bash
# Publish the manifests in ../gitops/ to the in-cluster git server.
#
#   ./publish.sh "commit message"        push current gitops/ contents
#   IMAGE=slo-demo:v2-bad ./publish.sh   rewrite the Rollout image, then push
#
# This is the lab's stand-in for "a developer merges a PR". Argo CD polls the
# repo and reconciles; nothing here talks to Kubernetes directly, which is the
# whole point of GitOps — the deploy is a git push, not a kubectl apply.
set -euo pipefail

cd "$(dirname "$0")"

GIT_NS=git-server
GIT_SVC=svc/git-server
PORT=${PORT:-9418}
WORK=/tmp/gitops-work
MSG=${1:-"update manifests"}

PF_PID=""
cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

kubectl port-forward -n "$GIT_NS" "$GIT_SVC" "${PORT}:9418" >/dev/null 2>&1 &
PF_PID=$!
for _ in $(seq 1 40); do
  (echo > "/dev/tcp/localhost/${PORT}") >/dev/null 2>&1 && break
  sleep 0.25
done

REMOTE="git://localhost:${PORT}/gitops.git"

rm -rf "$WORK"
# Clone if the repo already has commits; otherwise start a fresh history.
if git ls-remote "$REMOTE" 2>/dev/null | grep -q refs/heads/main; then
  git clone -q --branch main "$REMOTE" "$WORK"
else
  mkdir -p "$WORK"
  git -C "$WORK" init -q --initial-branch=main
  git -C "$WORK" remote add origin "$REMOTE"
fi

git -C "$WORK" config user.email "lab@k8s-labs.local"
git -C "$WORK" config user.name  "SRE Lab"

# Mirror gitops/ into the repo root; --delete so removals propagate as prunes.
rm -f "$WORK"/*.yaml
cp ../gitops/*.yaml "$WORK"/

# Optional image bump, applied to the repo copy so the change is a real commit
# rather than a live edit of the cluster.
if [[ -n "${IMAGE:-}" ]]; then
  sed -i -E "s|(^\s+image:\s+)slo-demo:.*|\1${IMAGE}|" "$WORK/rollout.yaml"
  echo "==> rollout.yaml image set to ${IMAGE}"
fi

cd "$WORK"
git add -A
if git diff --cached --quiet; then
  echo "==> nothing to commit; repo already matches gitops/"
else
  git commit -qm "$MSG"
  git push -q origin main
  echo "==> pushed: $(git log -1 --format='%h %s')"
fi

echo "==> remote HEAD: $(git ls-remote origin main | cut -c1-7)"
