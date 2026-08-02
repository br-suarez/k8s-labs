#!/usr/bin/env bash
# Install the delivery platform for this lab: Argo CD + Argo Rollouts.
#
# Argo CD and Argo Rollouts solve two different problems and this lab needs both:
#   Argo CD       — reconciles cluster state to what Git says (GitOps)
#   Argo Rollouts — replaces Deployment with a Rollout that can do canary steps
#                   and, critically, run analysis between them
#
# A plain Argo CD sync is all-or-nothing: it applies the manifest and the
# Deployment's rolling update replaces every pod with no gate. The canary
# behaviour and the automated rollback come from Argo Rollouts.
set -euo pipefail

ARGOCD_NS=argocd
ROLLOUTS_NS=argo-rollouts

echo "==> Adding Argo helm repo"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update >/dev/null

# dex (SSO), notifications and applicationSet are switched off: this is a
# single-user kind cluster with ~4 GB of headroom, and each is an extra
# always-on pod that this lab never touches.
#
# Note the asymmetry — dex and notifications take `.enabled=false`, but
# applicationSet has no `enabled` key in chart 10.x and must be scaled to zero
# replicas instead. Helm accepts `--set` for keys that do not exist in the
# chart without any warning, so `applicationSet.enabled=false` looked like it
# worked and the pod kept running. Always verify against `helm get values` AND
# the running pods, never against the absence of an error.
echo "==> Installing Argo CD (core components only)"
helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NS" --create-namespace \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set applicationSet.replicas=0 \
  --set server.resources.requests.cpu=50m \
  --set server.resources.requests.memory=128Mi \
  --set repoServer.resources.requests.cpu=50m \
  --set repoServer.resources.requests.memory=128Mi \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=256Mi \
  --set redis.resources.requests.cpu=20m \
  --set redis.resources.requests.memory=64Mi \
  --wait --timeout 10m

echo "==> Installing Argo Rollouts"
helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace "$ROLLOUTS_NS" --create-namespace \
  --set controller.resources.requests.cpu=50m \
  --set controller.resources.requests.memory=128Mi \
  --set dashboard.enabled=false \
  --wait --timeout 10m

# The kubectl plugin renders canary step progress and analysis results as a
# live table. `kubectl get rollout -o yaml` has the same data but is unreadable
# while an incident is in progress.
#
# Installed into ~/.local/bin rather than /usr/local/bin so the script never
# needs sudo — kubectl discovers plugins anywhere on PATH.
PLUGIN_DIR="${HOME}/.local/bin"
if ! kubectl argo rollouts version >/dev/null 2>&1; then
  echo "==> Installing kubectl-argo-rollouts plugin into ${PLUGIN_DIR}"
  mkdir -p "$PLUGIN_DIR"
  curl -sLo "${PLUGIN_DIR}/kubectl-argo-rollouts" \
    https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
  chmod +x "${PLUGIN_DIR}/kubectl-argo-rollouts"
  case ":${PATH}:" in
    *":${PLUGIN_DIR}:"*) ;;
    *) echo "  NOTE: add ${PLUGIN_DIR} to PATH to use 'kubectl argo rollouts'" ;;
  esac
fi
export PATH="${PLUGIN_DIR}:${PATH}"

echo
echo "==> Versions"
kubectl -n "$ARGOCD_NS"   get deploy -o name | sed 's|deployment.apps/|  argocd: |'
kubectl -n "$ROLLOUTS_NS" get deploy -o name | sed 's|deployment.apps/|  rollouts: |'
kubectl argo rollouts version 2>/dev/null || true

cat <<EOF

==> Argo CD admin password:
      kubectl -n ${ARGOCD_NS} get secret argocd-initial-admin-secret \\
        -o jsonpath='{.data.password}' | base64 -d; echo

==> Argo CD UI:
      kubectl port-forward -n ${ARGOCD_NS} svc/argocd-server 8080:443
      https://localhost:8080  (user: admin)
EOF
