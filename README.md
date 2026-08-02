# Kubernetes Labs — Bryan M. Suarez

Hands-on Kubernetes and SRE lab portfolio. Modules 01–12 were built during a
private course based on [KubeLabs](https://github.com/cachac/kubelabs); modules
20–31 are a self-directed site reliability engineering track.

**Goal:** demonstrate practical site reliability engineering — defining SLIs/SLOs
and error budgets, gating deployments on them, automating operational toil, and
managing observability and infrastructure as code.

Every lab is executed against a real cluster and ships the command output it
produced, including the mistakes made along the way.

## Stack

**Kubernetes track (01–12)** — Kind, kubectl, Helm, Kustomize

**SRE track (20–31)** — Prometheus, Grafana, Alertmanager, Argo CD, Argo
Rollouts, Terraform, Ansible, Datadog (as code), Docker multi-stage, GitHub
Actions, `strace` / `perf`

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
| 08 | [Namespaces](./08-namespaces/README.md) | ✅ Complete | Resource isolation, quota inspection, cluster restart recovery |
| 09 | [Practice](./09-practice/README.md) | ✅ Complete | Resource requests/limits, scaling events, control plane restart diagnosis |
| 10 | [Quotas and Limits](./10-quotas-limits/README.md) | ✅ Complete | ResourceQuota enforcement, LimitRange defaults, quota rejection captured |
| 11 | [Apps](./11-apps/README.md) | ✅ Complete | ConfigMaps, Secrets, base64 vs encryption, last-applied-configuration leak |
| 12 | [Services](./12-services/README.md) | ✅ Complete | ClusterIP, DNS resolution via CoreDNS, quota headroom during debugging |
| 13 | Storage | ⬜ Pending | |
| 14 | Networking | ⬜ Pending | |
| 14a | Practice 2 | ⬜ Pending | |
| 15 | Lifecycle | ⬜ Pending | |
| 16 | Taints & Tolerations (optional) | ⬜ Pending | |
| 17 | Final Practice | ⬜ Pending | |
| 18 | Part II (CI/CD, Kustomize) | ⬜ Pending | |

Mark each module as ✅ as you document it.

---

## Part II — SRE Track

A second track focused on production reliability engineering rather than cluster
administration: service level objectives, safe delivery, toil automation and
infrastructure as code. Numbering starts at 20 so the KubeLabs modules above keep
their slots.

### Deep labs

| # | Module | Status | Notes |
|---|--------|--------|-------|
| 20 | [SLIs, SLOs & Error Budgets](./20-slo-error-budgets/README.md) | ✅ Complete | Burn-rate alerting proven end to end: injected a 35% error rate, paged at 14.4x, watched the short window resolve it while the long window was still over threshold |
| 21 | [Safe Deployments with ArgoCD](./21-argocd-canary/README.md) | ✅ Complete | Canary gated on the module 20 SLI: bad release auto-rejected at 20% traffic, good one promoted. Found and fixed a 3x blast-radius bug caused by a pause shorter than the analysis time-to-verdict |
| 22 | [Toil Automation & Runbooks](./22-toil-automation/README.md) | ✅ Complete | Alertmanager webhook runs the module 20 runbook automatically: 11 manual commands → 0, full diagnosis on disk 13s after the page, unattended |
| 23 | [Observability with Terraform + Datadog](./23-terraform-datadog/README.md) | ✅ Complete *(plan only)* | 2 SLOs, 4 burn-rate monitors and a dashboard as code, validated and planned offline with policy assertions on the plan JSON. **No `apply` — no Datadog account** |

### Hands-on refreshers

Shorter than the deep labs — one concrete scenario each, executed and broken on
purpose, closing with a short note: what broke, how it was diagnosed, which command
was the key.

| # | Module | Status | Scenario |
|---|--------|--------|----------|
| 24 | [Kubernetes Failure Injection](./24-k8s-failure-injection/README.md) | ✅ Complete | CrashLoopBackOff, Service with no endpoints, Service *with* endpoints that still fails, pending PVC — each diagnosed from symptoms and fixed |
| 25 | [Docker Multi-stage & Debugging](./25-docker-multistage/README.md) | ✅ Complete | 1.66 GB → 235 MB and 6s → 2s rebuilds; debugged two containers that build cleanly and die on start (wrong CMD path, root-owned dir under a non-root user) |
| 26 | [Helm Package & Rollback](./26-helm-chart-rollback/README.md) | ✅ Complete | Hand-written chart; caught `helm upgrade` reporting "deployed" on a release whose pods never started, rolled back and verified on three independent objects |
| 27 | [Terraform Import & Drift](./27-terraform-import-drift/README.md) | ✅ Complete | Reusable module, adopted a hand-created object via `import`, caused drift two ways; `plan` vs `plan -refresh-only` on the same field, opposite directions |
| 28 | [Ansible Idempotency](./28-ansible-idempotency/README.md) | ✅ Complete | Naive vs declarative playbook: `changed=4` forever and a duplicated motd line vs `changed=0` on the second run; also caught Ansible silently ignoring a config file on a world-writable mount |
| 29 | [PromQL & Alerting](./29-promql-alerting/README.md) | ✅ Complete | RED + saturation queries; two classic mistakes shown against their correct form; latency alert driven from 198ms to 950ms and back, pending→firing measured at 2m06s |
| 30 | [CI/CD Safe Deploy Gate](./30-cicd-deploy-gate/README.md) | ✅ Complete | Gate blocked a release whose pods were `READY=true, RESTARTS=0` while failing 19.2% of requests; also caught my own gate false-negativing a healthy release |
| 31 | [Linux Performance Debugging](./31-linux-performance/README.md) | ✅ Complete | Syscall storm (200k `write` calls → 8x faster), a hang diagnosed from `/proc/pid/wchan`, and a CPU-bound case where strace finding *nothing* was the diagnosis |

## How each lab is documented

Each folder contains the manifests and code used, plus a `README.md`. Two
formats, depending on the depth of the lab:

- **Modules 01–23 (deep labs)** — **Problem → Solution → What I Learned**,
  including the issues hit along the way and how they were resolved.
- **Modules 24–31 (refreshers)** — a lighter note per scenario:
  **what broke → how it was diagnosed → the command that mattered**.

Every SRE-track module ships an `evidence/` directory with the real command
output from the run described, and a `run-lab.sh` that reproduces it from
scratch. Where something could not be executed — module 23 has no Datadog
account and is `plan`-only — the README says so explicitly rather than implying
otherwise.
