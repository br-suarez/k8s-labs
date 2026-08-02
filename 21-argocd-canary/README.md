# Lab 21: Safe Deployments — ArgoCD Canary with Automated SLO Rollback

**Module:** 21 — Safe Deployments with ArgoCD (SRE Track)
**Date:** 2026-08-02
**Stack:** Argo CD, Argo Rollouts, Prometheus, kind, in-cluster git daemon

---

## Problem

A Kubernetes `Deployment` has exactly one safety mechanism during a rolling
update: the readiness probe. It will cheerfully replace every pod in production
with a build that returns `500` to one request in five, as long as the process
starts and answers `/healthz`. Readiness answers *"is the process up"*. It has
nothing to say about *"are users being served"*.

The usual patch is a human: someone watches a dashboard during the deploy and
hits rollback if it looks wrong. That fails for the obvious reasons — it does
not scale, it does not work at 3am, and "looks wrong" is not a threshold.

This lab wires the deploy gate to the **SLO from module 20**. The canary is
promoted or rejected on the availability SLI — the same definition, the same
0.5% error budget — evaluated automatically. No dashboards, no human.

Two things had to be proven, not described:

1. A bad release is **rejected and rolled back automatically**.
2. A good release is **accepted** — a gate that blocks everything is not a gate.

---

## Solution

### Architecture

```
                    git push
  gitops/*.yaml ─────────────► git daemon (in-cluster, ns git-server)
                                      │
                                      │ Argo CD polls / hard refresh
                                      ▼
                            Argo CD Application "slo-demo"
                                      │ syncs
                                      ▼
              ns canary-demo:  Rollout (Argo Rollouts)
                                 ├── stable ReplicaSet ──► Service slo-demo-stable
                                 └── canary ReplicaSet ──► Service slo-demo-canary
                                                                  │
                                              ServiceMonitor ─────┘
                                                     │
                                                     ▼
                                   Prometheus (ns monitoring, from module 20)
                                                     ▲
                                                     │ PromQL
                                          AnalysisTemplate "slo-availability"
                                          successCondition: result[0] <= 0.005
```

| Path | What it is |
|------|-----------|
| [`platform/install.sh`](./platform/install.sh) | Argo CD + Argo Rollouts + kubectl plugin |
| [`platform/git-server.yaml`](./platform/git-server.yaml) | In-cluster git daemon so the lab needs no external Git host |
| [`gitops/rollout.yaml`](./gitops/rollout.yaml) | The Rollout: canary steps and the analysis hook |
| [`gitops/analysis-template.yaml`](./gitops/analysis-template.yaml) | **The gate** — PromQL against the module 20 SLI |
| [`gitops/services.yaml`](./gitops/services.yaml) | root / canary / stable Services |
| [`gitops-app/application.yaml`](./gitops-app/application.yaml) | Argo CD Application, incl. the `ignoreDifferences` that makes this work at all |
| [`gitops-app/publish.sh`](./gitops-app/publish.sh) | "merge a PR" — rewrites the image and pushes |
| [`app/Dockerfile.v2-bad`](./app/Dockerfile.v2-bad) | The regressed release (20% errors) |

### The gate

```yaml
successCondition: result[0] <= 0.005
query: |
  sum(rate(http_requests_total{service="{{args.canary-service}}",path="/api",status=~"5.."}[1m]))
  /
  sum(rate(http_requests_total{service="{{args.canary-service}}",path="/api"}[1m]))
```

Two details carry the whole design:

**It is scoped to the canary Service.** Argo Rollouts rewrites that Service's
selector to match only canary pods. Querying the root Service instead would
average the canary in with the healthy stable pods — with 1 canary pod in 5, a
release failing *100%* of its own traffic shows up as a 20% error ratio and can
slip under a loose threshold. An averaged canary metric is worse than none,
because it looks like it is working.

**`0.005` is not a new number.** It is the error budget from
[module 20's SLO spec](../20-slo-error-budgets/slo/slo-definition.md). The same
threshold that pages on-call also blocks the deploy.

### The three releases

All three images share a byte-identical binary and differ only in environment
variables, so a rejected canary has exactly one possible cause:

| Image | `BASELINE_ERROR_RATE` | Expected |
|-------|----------------------|----------|
| `slo-demo:v1` | 0.001 | healthy baseline |
| `slo-demo:v2-bad` | **0.20** | rejected — 40x the error budget |
| `slo-demo:v3-fixed` | 0.001 | promoted |

---

## Results

### Scenario A — the bad release is rejected

Pushed `slo-demo:v2-bad` to Git. Argo CD synced it, Argo Rollouts started a
canary, and the analysis measured it ([`04-v2-bad-rejected.txt`](./evidence/04-v2-bad-rejected.txt)):

```
metric=availability-sli phase=Failed successful=0 failed=3 error=0
  [Failed] value=[0.20234436431208763]  at 2026-08-02T04:39:09Z
  [Failed] value=[0.1973940101127966]   at 2026-08-02T04:39:40Z
  [Failed] value=[0.1973249632292684]   at 2026-08-02T04:40:11Z

Status:   ✖ Degraded
Message:  RolloutAborted: Rollout aborted update to revision 2:
          Background analysis phase error/failed: Metric "availability-sli"
          assessed Failed due to failed (3) > failureLimit (2)
```

All five pods were back on `slo-demo:v1` with no human involved.

### Scenario B — the good release is promoted

```
metric=availability-sli phase=Successful successful=5 failed=0 error=0
  [Successful] value=[0.000529100529100529]   at 2026-08-02T04:41:37Z
  [Successful] value=[0.0007561436672967863]  at 2026-08-02T04:42:08Z
  [Successful] value=[0.0006461235634109518]  at 2026-08-02T04:42:38Z
  [Successful] value=[0.0012444814377680518]  at 2026-08-02T04:43:09Z
  [Successful] value=[0.001147828188243823]   at 2026-08-02T04:43:40Z

Status:  ✔ Healthy    Step: 5/5    SetWeight: 100
Images:  slo-demo:v3-fixed (stable)
```

Error ratios of 0.05%–0.12%, comfortably inside the 0.5% budget. Promoted to
100%. The gate measures releases; it does not just block them.

### The finding that mattered — blast radius

The gate worked on the first try. What it did *not* do was contain the damage to
the first canary step. Reconstructed from
[`03-v2-bad-progression.txt`](./evidence/03-v2-bad-progression.txt):

| Time | Canary weight | Event |
|------|---------------|-------|
| 04:38:13 | 20% | canary starts |
| 04:39:09 | 20% | measurement 1 fails (20.2%) |
| 04:39:40 | 20% | measurement 2 fails (19.7%) |
| **04:39:42** | **60%** | **rollout advances anyway** |
| 04:40:11 | 60% | measurement 3 fails → analysis Failed |
| 04:40:28 | 0% | aborted, rolled back |

The bad release reached **60% of traffic**, three times the first step's 20%.

The cause is arithmetic, not a bug. The analysis cannot reach a verdict faster than:

```
initialDelay + (failureLimit + 1) x interval
60s          + (2 + 1)            x 30s      = 150s
```

The first pause was `90s`. The step timer expired 60 seconds before the analysis
was allowed to conclude, so the rollout advanced on a clock while the gate was
still gathering evidence. **A pause shorter than the analysis time-to-verdict
means the canary weight is decided by a timer, not by a measurement.**

Fixed by raising the first pause to `180s` and re-running
([`10-retest-result.txt`](./evidence/10-retest-result.txt)):

```
maximum canary weight reached before abort: 20%
(previous run with a 90s pause reached 60%)

poll #1 @ 04:53:50Z  phase=Paused   step=1  canary_weight=20%
...
poll #8 @ 04:55:46Z  phase=Paused   step=1  canary_weight=20%
poll #9 @ 04:56:04Z  phase=Degraded step=0  canary_weight=0%
```

Same rejection, same measurements (19.7% / 21.1% / 20.4%) — blast radius cut
from 60% of traffic to 20%.

---

## Issues encountered

**1. Argo CD and Argo Rollouts fight over the Service selector.**
Rollouts implements the canary/stable split by appending the ReplicaSet's
`rollouts-pod-template-hash` to those Services' selectors at runtime. Git cannot
contain that hash — it does not exist until the ReplicaSet does. Argo CD sees a
live Service that differs from Git, calls it drift, and `selfHeal` reverts it.
The two controllers then loop, the canary Service ends up selecting every pod,
and the analysis silently measures stable and canary averaged together. The
`ignoreDifferences` block on `/spec/selector` in
[`application.yaml`](./gitops-app/application.yaml) is not optional.

**2. Helm silently accepts `--set` for keys that do not exist.**
`--set applicationSet.enabled=false` looked like it worked — no error, and
`helm get values` showed the key present. The applicationset pod kept running
anyway, because chart `argo-cd` 10.x removed that key entirely; only `dex` and
`notifications` still have `.enabled`. Helm validates nothing about `--set`
paths. **Verify against running pods, never against the absence of an error.**
Correct answer was `--set applicationSet.replicas=0`.

**3. `alpine/git` cannot run a git daemon.**
Alpine ships the daemon in a separate `git-daemon` package, so the container
crash-looped with `git: 'daemon' is not a git command`. Fixed with a three-line
image that installs the right package.

**4. `status.canary.weights` is empty without a traffic router.**
The first blast-radius measurement reported `0%` for the whole run. That field is
only populated when Istio / NGINX / ALB is managing the split. This lab uses a
replica-based canary, where the weight *is* the ReplicaSet's share of the pods —
so the honest probe counts pods, not status fields. The script reported a
confident, precise, wrong number until this was caught.

---

## What I learned

- **A gate on "is it up" and a gate on "is it working" are different systems.**
  Every pod in the rejected canary was `Running`, `1/1 Ready`, and passing both
  probes for the entire time it was serving 20% errors. Kubernetes had no signal
  that anything was wrong, because by its definition nothing was. Reusing the
  SLI as the gate is what made the failure visible to automation.

- **Time-to-verdict must be shorter than the step it guards — and it is a
  formula, not a feeling.** `initialDelay + (failureLimit + 1) x interval`
  against the pause duration. Getting this backwards does not break the gate
  loudly; it quietly triples the blast radius while every dashboard still shows
  the rollback working. This was the single most valuable thing in the module,
  and it only surfaced because the run was instrumented to record the *maximum*
  weight rather than just the outcome.

- **Argo CD's `Synced` and `Healthy` mean genuinely different things, and after
  a rollback they disagree.** When the canary was rejected, the Application read
  `Synced / Degraded`: Git said `v2-bad`, the cluster ran `v1`, and Argo CD
  considered that *synced* because the Rollout manifest it applied matched Git
  exactly. Rollouts owns which ReplicaSet is scaled up; Argo CD owns the
  manifest. **The rollback happened in the cluster, not in Git** — so the
  regression is still the desired state, and deleting the Rollout would redeploy
  it. A real recovery ends with a revert commit.

- **A canary metric scoped to the wrong Service fails silently.** With 1 canary
  pod in 5, a release failing 100% of its own requests reads as a 20% error
  ratio through the root Service. The metric still moves, the graph still looks
  responsive, and the threshold that should have caught it never trips.

- **Measuring the outcome is not the same as measuring the behaviour.** Both
  runs of scenario A ended identically — rejected, rolled back, five healthy
  pods. Only the instrumentation of *how much traffic was exposed on the way
  there* revealed that the first configuration was wrong.

---

## Reproduce

```bash
./platform/install.sh                       # Argo CD + Argo Rollouts
kubectl apply -f platform/git-server.yaml   # in-cluster Git
./app/build-versions.sh                     # v1 / v2-bad / v3-fixed
./gitops-app/publish.sh "initial manifests"
kubectl apply -f gitops-app/application.yaml
kubectl apply -f lab/loadgen.yaml

./evidence/run-experiment.sh                # bad release rejected, good one promoted
./evidence/run-blast-radius-retest.sh       # proves the pause tuning
```

Watch it live:

```bash
kubectl argo rollouts get rollout slo-demo -n canary-demo --watch
```

Requires the module 20 monitoring stack (Prometheus in `monitoring`).
Teardown: `kind delete cluster --name slo-lab`
