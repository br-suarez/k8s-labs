# DevOps / SRE Mastery — Bryan M. Suarez

A production-shaped reliability platform, built one layer at a time, and the
curriculum that produces it.

This repository is two things at once:

1. **A portfolio.** Every module ships working code, the command output it
   produced, and a `Problem → Solution → What I Learned` write-up — including the
   mistakes made on the way.
2. **A transferable curriculum.** Every module opens with a diagnostic test. Pass
   it and you skip to the advanced work; fail it and you get the full path from
   fundamentals. The same material serves a beginner and an experienced engineer
   without being rewritten for either.

---

## The platform: Pulse

Rather than sixty disconnected labs, the track builds **one multi-service
platform** and adds a layer to it every module. Pulse is an endpoint health
monitoring service — deliberately an SRE tool, so that instrumenting it and
reasoning about its failure modes is the point rather than a detour.

| Service | Role | Why it earns its place |
|---|---|---|
| `pulse-api` | Go REST API — CRUD for checks, serves results | Instrumentation and routing surface |
| `pulse-worker` | Go consumer — pulls jobs, probes targets, writes results | Queue depth is a **saturation** signal, the hardest SLI to teach |
| `pulse-web` | Static dashboard | Second backend for host/path routing and canary splits |
| `postgres` | Result store | Real state: StatefulSet, PVC, backup and restore drills |
| `redis` | Job queue | Observable backlog, natural failure injection point |

At the end of every module the platform is in a **deployable, demonstrable
state**. It starts as a process on a VM and ends deployed by GitOps to GKE,
emitting its own traces and metrics, provisioned by Terraform, and released
through canary deployments gated on its own SLO.

### How it grows

| Module | Layer added |
|---|---|
| 01 | Repo layout, `verify.sh` harness, Makefile |
| 02 | NGINX edge: reverse proxy, TLS, caching |
| 03 | Containerized, distroless images, Compose stack |
| 04 | Running on Kubernetes (kind): Deployments, Services, HPA |
| 05 | NGINX **replaced** by Gateway API — `HTTPRoute` by path and header |
| 06 | Postgres as StatefulSet, shared NFS storage, PDBs, backup drill |
| 07 | kube-prometheus-stack, ServiceMonitors, RED dashboards, an SLO |
| 08 | OpenTelemetry SDK + Collector, traces, metric→trace exemplars |
| 08b | *No new layer — the platform is broken deliberately and diagnosed* |
| 09 | GitHub Actions: build, test, scan, SBOM, publish by digest |
| 10 | Argo CD app-of-apps, Kustomize overlays, self-heal |
| 11 | Argo Rollouts canary gated on the module 07 SLO |
| 12 | Trivy, Cosign signing, Kyverno admission policy |
| 13 | Terraform modules provision cluster and platform infrastructure |
| 14 | Same Terraform targets GKE, with a teardown drill |
| 15 | Ansible-provisioned legacy worker + equivalent Jenkinsfile |
| 16 | Game Day: injected failures, incident timeline, postmortem |

---

## Modules

| # | Module | Blocks | Status |
|---|---|---|---|
| 00 | [Bootstrap & Environment](./modules/00-bootstrap/README.md) | 2 | ⬜ |
| 01 | [Linux & Scripting](./modules/01-linux-scripting/README.md) | 4 | ⬜ |
| 02 | [NGINX as Edge](./modules/02-nginx-edge/README.md) | 4 | ⬜ |
| 03 | [Docker & Image Supply Chain](./modules/03-docker-supply-chain/README.md) | 4 | ⬜ |
| 04 | [Kubernetes Core](./modules/04-kubernetes-core/README.md) | 4 | ⬜ |
| 05 | [Gateway API](./modules/05-gateway-api/README.md) | 5 | ⬜ |
| 06 | [Kubernetes Advanced: State, Storage, HA](./modules/06-kubernetes-advanced/README.md) | 5 | ⬜ |
| 07 | [Prometheus & Grafana](./modules/07-prometheus-grafana/README.md) | 4 | ⬜ |
| 08 | [OpenTelemetry](./modules/08-opentelemetry/README.md) | 6 | ⬜ |
| 08b | [**Game Day I**](./modules/08b-game-day-i/README.md) | 2 | ⬜ |
| 09 | [CI with GitHub Actions](./modules/09-github-actions/README.md) | 4 | ⬜ |
| 10 | [GitOps with Argo CD](./modules/10-gitops-argocd/README.md) | 5 | ⬜ |
| 11 | [Progressive Delivery](./modules/11-progressive-delivery/README.md) | 4 | ⬜ |
| 12 | [DevSecOps & Supply Chain](./modules/12-devsecops/README.md) | 5 | ⬜ |
| 13 | [Terraform](./modules/13-terraform/README.md) | 5 | ⬜ |
| 14 | [Google Cloud](./modules/14-gcp/README.md) | 6 | ⬜ |
| 15 | [Jenkins & Ansible: Operate and Migrate](./modules/15-jenkins-ansible/README.md) | 3 | ⬜ |
| 16 | [Game Day II & Hardening](./modules/16-game-day/README.md) | 4 | ⬜ |

**76 blocks of 120 minutes ≈ 152 hours.** See [PLAN.md](./PLAN.md) for the
week-by-week calendar and [TRACKER.md](./TRACKER.md) for progress.

### What "done" means

A module is complete when all four exit criteria hold — not when the labs run:

1. I can design and implement the solution **without documentation open**.
2. I can debug **a failure I have not seen before** in this technology, under pressure.
3. I can explain the **trade-offs** of my decision against two named alternatives.
4. I can defend it in a senior SRE interview and in an architecture review.

Every module translates these into something verifiable. Not "understand
Prometheus", but "I can write a recording rule that takes a dashboard from 8s to
under 1s, and explain why it works".

---

## Repository layout

```
├── PLAN.md         # week-by-week calendar, slip protocol
├── TRACKER.md      # progress, self-assessment, spaced-repetition dates
├── SETUP.md        # reproducible local environment
├── platform/       # Pulse — the capstone
├── modules/NN-*/
│   ├── README.md         # objectives, exit criteria, portfolio write-up
│   ├── DIAGNOSTICO.md    # entry test — decides your path through the module
│   ├── labs/             # progressive labs with automated verification
│   ├── BREAK-FIX.md      # a broken scenario to diagnose
│   ├── CAUSA-RAIZ.md     # the root cause, kept separate to avoid spoilers
│   ├── PREGUNTAS.md      # senior interview questions
│   └── NOTAS.md          # working notes
└── archive/        # completed prior work, preserved
```

### Language convention

English for everything a third party reads or runs: code, commands, commit
messages, and the module `README.md` files. Spanish for the study instruments —
`PLAN.md`, `TRACKER.md`, `DIAGNOSTICO.md`, `BREAK-FIX.md`, `PREGUNTAS.md`,
`NOTAS.md` — because that is where thinking happens, and it happens faster in
the language you think in.

---

## Prior work (`archive/`)

Completed before this track began, preserved with its original documentation.

### KubeLabs modules 01–12

Cluster fundamentals built against a real Kind cluster: Pods, ReplicaSets,
Deployments, DaemonSets, namespaces, quotas, ConfigMaps and Secrets, Services
and CoreDNS resolution. → [`archive/`](./archive/)

### SRE track 20–31

Reliability engineering rather than cluster administration.

| # | Module | What it proved |
|---|---|---|
| 20 | [SLIs, SLOs & Error Budgets](./archive/sre-track/20-slo-error-budgets/README.md) | Multi-window burn-rate alerting proven end to end: 35% error rate injected, paged at 14.4x, short window resolved while the long window was still over threshold |
| 21 | [Safe Deployments with Argo CD](./archive/sre-track/21-argocd-canary/README.md) | Canary gated on the module 20 SLI; a bad release auto-rejected at 20% traffic. Found a 3x blast-radius bug caused by a pause shorter than the analysis time-to-verdict |
| 22 | [Toil Automation & Runbooks](./archive/sre-track/22-toil-automation/README.md) | Alertmanager webhook runs the runbook unattended: 11 manual commands → 0, full diagnosis on disk 13s after the page |
| 23 | [Observability as Code](./archive/sre-track/23-terraform-datadog/README.md) | 2 SLOs, 4 burn-rate monitors and a dashboard as code, validated offline with policy assertions on the plan JSON *(plan only — no account)* |
| 24 | [Kubernetes Failure Injection](./archive/sre-track/24-k8s-failure-injection/README.md) | CrashLoopBackOff, Service with no endpoints, Service *with* endpoints that still fails, pending PVC — each diagnosed from symptoms |
| 25 | [Docker Multi-stage & Debugging](./archive/sre-track/25-docker-multistage/README.md) | 1.66 GB → 235 MB, 6s → 2s rebuilds; two containers that build clean and die on start |
| 26 | [Helm Package & Rollback](./archive/sre-track/26-helm-chart-rollback/README.md) | Caught `helm upgrade` reporting "deployed" for a release whose pods never started |
| 27 | [Terraform Import & Drift](./archive/sre-track/27-terraform-import-drift/README.md) | `plan` vs `plan -refresh-only` on the same field, pointing opposite directions |
| 28 | [Ansible Idempotency](./archive/sre-track/28-ansible-idempotency/README.md) | `changed=4` forever vs `changed=0`; caught Ansible silently ignoring a config on a world-writable mount |
| 29 | [PromQL & Alerting](./archive/sre-track/29-promql-alerting/README.md) | RED and saturation queries; latency alert driven 198ms → 950ms and back, pending→firing measured at 2m06s |
| 30 | [CI/CD Safe Deploy Gate](./archive/sre-track/30-cicd-deploy-gate/README.md) | Gate blocked a release with `READY=true, RESTARTS=0` that was failing 19.2% of requests |
| 31 | [Linux Performance Debugging](./archive/sre-track/31-linux-performance/README.md) | Syscall storm (200k `write` calls → 8x faster), a hang read from `/proc/pid/wchan`, and a CPU-bound case where strace finding *nothing* was the diagnosis |

Each archived module ships an `evidence/` directory with real command output and
a `run-lab.sh` that reproduces it. Where something could not be executed, the
README says so explicitly rather than implying otherwise.
