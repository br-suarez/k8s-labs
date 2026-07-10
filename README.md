# Kubernetes Labs — Bryan M. Suarez

Hands-on Kubernetes lab portfolio, built during a private course based on [KubeLabs](https://github.com/cachac/kubelabs).

**Goal:** demonstrate practical competency in Kubernetes cluster administration for DevOps/SRE roles (Upwork, Fiverr, remote contracts).

## Stack
- Kind (Kubernetes in Docker)
- kubectl, Helm, Kustomize
- Basic CI/CD

## Modules (aligned with official KubeLabs numbering)

| # | Module | Status | Notes |
|---|--------|--------|-------|
| 01 | [Kind Installation](./01-installation/README.md) | ✅ Complete | Cluster set up with Kind, troubleshooting inotify limits |
| 02 | Remote Connection (optional, MicroK8s only) | ⬜ N/A | Not applicable, using Kind |
| 03 | [First Steps — building a Pod](./03-first-steps-pod/README.md) | ✅ Complete | Pod lifecycle, port-forward, local port conflict troubleshooting |
| 04 | [ReplicaSets](./04-replicasets/README.md) | ✅ Complete | Pod adoption via label collision, self-healing test |
| 05 | [Deployments](./05-deployments/README.md) | ✅ Complete | Rolling update, rollback, deprecated --record flag |
| 06 | [DaemonSet](./06-daemonset/README.md) | ✅ Complete | One-pod-per-node, scale subresource not supported, self-healing |
| 07 | [Quick CLI Commands](./07-cli-commands/README.md) | ✅ Complete | metrics-server install/patch, scale, contexts, events |
| 08 | Namespaces | ⬜ Pending | |
| 09 | Practice | ⬜ Pending | |
| 10 | Quotas and Limits | ⬜ Pending | |
| 11 | Apps (optional) | ⬜ Pending | |
| 12 | Services | ⬜ Pending | |
| 13 | Storage | ⬜ Pending | |
| 14 | Networking | ⬜ Pending | |
| 14a | Practice 2 | ⬜ Pending | |
| 15 | Lifecycle | ⬜ Pending | |
| 16 | Taints & Tolerations (optional) | ⬜ Pending | |
| 17 | Final Practice | ⬜ Pending | |
| 18 | Part II (CI/CD, Kustomize) | ⬜ Pending | |

Mark each module as ✅ as you document it.

## How each lab is documented

Each folder contains:
- The YAML manifests / files used
- A `README.md` following the format: **Problem → Solution → What I Learned**
- Key commands or relevant troubleshooting
