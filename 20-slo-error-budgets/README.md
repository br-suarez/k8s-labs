# Lab 20: SLIs, SLOs and Error Budgets

**Module:** 20 — SLIs/SLOs & Error Budgets (SRE Track)
**Date:** 2026-08-01
**Stack:** kind (k8s v1.34), kube-prometheus-stack, Prometheus, Grafana, Go

---

## Problem

Most teams monitor *causes* — CPU, memory, pod restarts, disk — and then wonder why
their dashboards were all green during an outage. The alerts fire on things nobody
outside the team can feel, and stay silent on the one thing users actually notice:
requests failing or taking too long.

Even when a team does adopt SLOs, the alert is usually still wrong. `error_rate > 1%`
for 5 minutes is either too sensitive (a brief blip pages someone at 3am) or too slow
(a 2% error rate quietly eats a month of budget without ever tripping), and either way
the page carries no information about *how much trouble the service is actually in*.

This lab builds the full path end to end and proves it works:

1. Define SLIs from the user's perspective, not from what happens to be easy to measure.
2. Set SLOs and turn them into a concrete, countable error budget.
3. Write multi-window multi-burn-rate alerts instead of static thresholds.
4. **Break the service on purpose and watch the page fire — then watch it resolve itself.**

The requirement was real evidence, not a description of what would happen.

---

## Solution

### Architecture

```
kind cluster "slo-lab" (1 control-plane + 2 workers)
│
├── ns slo-demo
│   ├── slo-demo    x3   Go service, instrumented, /chaos endpoint for fault injection
│   └── loadgen     x4   ~590 req/s of steady background traffic
│
└── ns monitoring
    ├── Prometheus       scrapes slo-demo via ServiceMonitor, evaluates SLI + burn rules
    ├── Alertmanager
    └── Grafana          SLO / error-budget dashboard
```

| Path | What it is |
|------|-----------|
| [`slo/slo-definition.md`](./slo/slo-definition.md) | The SLO spec — SLIs, targets, budget math, burn-rate table, and what was deliberately left out |
| [`slo/recording-rules.yaml`](./slo/recording-rules.yaml) | SLI error ratios over 7 windows + burn rate + budget remaining |
| [`slo/burn-rate-alerts.yaml`](./slo/burn-rate-alerts.yaml) | 4 availability + 2 latency multi-window burn-rate alerts |
| [`app/src/main.go`](./app/src/main.go) | Instrumented service with a runtime fault-injection endpoint |
| [`loadgen/chaos.sh`](./loadgen/chaos.sh) | `break` / `slow` / `heal` / `status` / `alerts` driver |
| [`evidence/run-experiment.sh`](./evidence/run-experiment.sh) | Runs the whole incident and captures evidence per phase |
| [`evidence/07-burn-timeline.md`](./evidence/07-burn-timeline.md) | The incident rendered from Prometheus as an ASCII chart |

### The two SLIs

**Availability** — proportion of `/api` requests not returning 5xx.
4xx counts as a *success*: a malformed client request means the service worked correctly.

**Latency** — proportion of `/api` requests completing under 300 ms.
This is a **bucket ratio**, not a percentile. The histogram in `main.go` uses `0.3` as an
exact bucket boundary so the SLI is a direct read of `..._bucket{le="0.3"}` with no
interpolation. Percentiles cannot be averaged across instances or time windows without
lying; ratios can.

`/healthz` is deliberately **not** instrumented — kubelet probes it constantly, and
folding thousands of always-200 probes into the SLI would dilute the ratio and hide
real user-facing failure.

### SLOs and the budget

| SLI | Target | Window | Error budget |
|-----|--------|--------|--------------|
| Availability | 99.5% | 28d rolling | 0.5% = **201.6 min** of full outage |
| Latency | 99% under 300ms | 28d rolling | 1.0% = **403.2 min** |

### Burn-rate alerting

`burn_rate = observed_error_ratio / error_budget`. A burn rate of 1 spends the whole
budget exactly at the end of the window; 14.4 spends it in under 2 days.

Every alert requires a **long window** AND a **short window**:

| Severity | Long | Short | Burn | Fires at (availability) |
|----------|------|-------|------|--------------------------|
| Page | 1h | 5m | 14.4x | error ratio > **7.2%** |
| Page | 6h | 30m | 6x | > 3.0% |
| Ticket | 1d | 2h | 3x | > 1.5% |
| Ticket | 3d | 6h | 1x | > 0.5% |

---

## The experiment

Driven by `evidence/run-experiment.sh`, ~590 req/s throughout.

### Phase 1 — baseline ([`01-baseline-healthy.txt`](./evidence/01-baseline-healthy.txt))

```
availability SLI (error ratio, budget = 0.5%):
  5m  window                             0.1021%
  1h  window                             0.1033%
burn rate:
  availability 1h                        0.21x
error budget remaining (6h lab proxy):   0.79
  (none — all SLO alerts inactive)
```

Burning at 0.21x — sustainable, and *deliberately not zero*. A service that spends none
of its budget is over-provisioned and under-shipping.

### Phase 2 — inject 35% errors

```bash
./loadgen/chaos.sh break 0.35
```

Verified uniform across all three replicas before trusting any of the numbers:

```
per-pod error ratio over 1m:
  slo-demo-...-ll5hq  =>  0.35116583133580304
  slo-demo-...-9zxzf  =>  0.3522688307235113
  slo-demo-...-666m6  =>  0.35056508999581415
```

### Phase 3 — the alerts escalate in the right order

Alerts entered `PENDING` **cheapest-threshold-first**, which is exactly correct — a 1x
burn threshold (0.5%) is crossed long before a 14.4x one (7.2%):

| Alert | Burn | Threshold | Entered PENDING |
|-------|------|-----------|-----------------|
| ChronicBurn | 1x | 0.5% | 03:25:13Z |
| BudgetDrain | 3x | 1.5% | 03:25:13Z |
| SlowBurn | 6x | 3.0% | 03:25:43Z |
| **FastBurn** | **14.4x** | **7.2%** | **03:26:28Z** |

Only `FastBurn` ever reached `FIRING` — at **03:28:50Z**, ~2m22s after going pending,
which is the configured `for: 2m` plus one evaluation interval
([`04-alert-firing.txt`](./evidence/04-alert-firing.txt)):

```
=== SLO alerts pending or firing @ 2026-08-02T03:28:51Z ===
  [FIRING] SLODemoAvailabilityFastBurn
      burn_rate=14.4x  windows=1h/5m  severity=critical
      active since: 2026-08-02T03:26:28.448676698Z
      value:        1.7596076298816213e-01

availability SLI:  5m 24.07%   1h 17.60%
burn rate 1h:      35.19x
error budget remaining (6h proxy):  -34.19
```

The other three stayed `PENDING` for the whole incident and never paged — their `for:`
durations (15m / 1h / 3h) are longer than the incident lasted. **That is the design
working:** a short sharp incident pages once, on the fast-burn alert, and does not
generate four separate notifications for the same event.

### Phase 4/5 — heal, and watch the short window earn its place

`./loadgen/chaos.sh heal` — then, from [`07-burn-timeline.md`](./evidence/07-burn-timeline.md):

```
time (UTC)   5m SLI  1h SLI    burn  5m error ratio  0%                              40%
  03:30:00   29.66%  17.79%  35.59x  #################################
  03:31:30   18.99%  15.06%  30.12x  #####################
  03:32:30   15.16%  14.29%  28.57x  #################
  03:33:00    7.47%  12.93%  25.87x  ########|          <- 5m still above 7.2%
  03:33:30    3.57%  12.34%  24.67x  ####    |          <- 5m below 7.2% -> alert clears
  03:34:00    0.10%  11.80%  23.61x          |
  03:38:00    0.10%   8.95%  17.90x          |          <- 1h STILL above threshold
  03:42:00    0.11%   7.12%  14.23x          |          <- 1h finally below threshold
```

The alert polling in [`06-recovery.txt`](./evidence/06-recovery.txt) caught the
transition: `FIRING` at 03:32:53Z, gone by 03:33:41Z — the moment the 5m window dropped
below 7.2%, while the 1h window was **still at 12.34%**, well above the same threshold.

The 1h window did not fall below 7.2% until **03:42:00Z**. A single-window alert on the
1h ratio alone would therefore have kept paging for **8.3 more minutes** after the
service was already healthy — longer than the incident's own 6.5 minutes above threshold.

Peak burn rate: **37.72x**.

---

## Issues encountered

**1. The load generator was measuring itself.**
The first version was `while true; do curl ...; done` and produced **13 req/s across 4
pods**. Forking a process per request costs more than the request. At that volume a 5m
window holds ~4,000 samples and the error ratio jumps around on individual requests.
Switching to curl URL globbing with parallel transfers —
`curl -sZ --parallel-max 16 "http://slo-demo:8080/api?i=[1-200]"` — gave **~590 req/s**,
a 44x improvement on the same CPU.

**2. `go mod tidy` silently deleted the only dependency.**
The Dockerfile copied `go.mod`, ran `go mod tidy`, *then* copied `main.go` — the standard
layer-caching pattern. But `tidy` prunes every requirement no source file imports, and
with no source present it removed `client_golang`:

```
main.go:22:2: no required module provides package github.com/prometheus/client_golang/prometheus
```

The dependency was listed in `go.mod` in the build context and still absent at build time.
Fixed by copying source and `go.mod` together before tidying.

**3. Grafana lost the dashboard on `helm upgrade`.**
The dashboard was imported through the Grafana API, which writes to Grafana's SQLite DB.
That DB lives in an `emptyDir` in this chart configuration, so rolling the pod for an
unrelated values change discarded it. Re-importing worked, but the real lesson is that
**API-imported dashboards are not configuration** — in a real environment they belong in a
`ConfigMap` with the `grafana_dashboard` label, or in Git via the provisioning sidecar.

**4. Rules over windows longer than retention return nothing.**
`slo:..._budget_remaining:ratio28d` is correct and returns no data here, because
Prometheus is configured with 6h retention. A 28-day SLO needs 28 days of retention (or
a downsampling layer like Thanos). The rule is kept in its production-correct form with
a 6h proxy alongside it — see the comment in `recording-rules.yaml`.

---

## What I learned

- **The short window is the whole point of multi-window alerting, and I now have the
  number to prove it.** At 03:33:41 the 5m window said "recovered" while the 1h window
  still read 12.34% — over the same 7.2% threshold. The 1h window did not clear until
  03:42:00, so a single-window alert would have paged for **8.3 minutes longer than
  necessary on a 6.5-minute incident** — more noise after the fix than during the fault.
  Alert fatigue is mostly manufactured by alerts that will not shut up once the problem
  is solved.

- **Alerts entering PENDING in threshold order is a feature, not noise.** Seeing 1x, 3x,
  6x and 14.4x go pending in sequence made the ladder click: lower burn rates always trip
  first, and their long `for:` durations are what stop a brief incident from generating
  four pages. Severity is encoded in *how long you tolerate it*, not just in the threshold.

- **Getting the histogram buckets right is an SLO design decision made in application
  code, months before anyone writes the alert.** Because `0.3` is a real bucket boundary,
  the latency SLI is exact. Had the buckets been Prometheus defaults, the nearest
  boundaries are 0.25 and 0.5 and every latency SLO number would have been an
  interpolation — and `histogram_quantile` cannot be aggregated across pods or re-windowed
  without producing a number that is confidently wrong.

- **An SLI is a ratio, and a ratio needs traffic.** With no load the rules return `NaN`,
  not 100%, and the alerts silently cannot evaluate. Absence of data is not evidence of
  health — which is why a low-traffic service needs its SLO window widened, or a separate
  "is anyone even calling this?" signal.

- **Error budget remaining went to -34.19.** Seeing the budget go sharply negative made
  the framing concrete in a way the arithmetic never did: the budget is a *spending
  allowance*, and it converts "the service felt slow" into "we have 201.6 minutes per 28
  days and we just spent all of them", which is a conversation a product owner can
  actually participate in.

- **Excluding `/healthz` from the SLI mattered more than expected.** At 590 req/s of real
  traffic plus ~1 probe/sec/pod the dilution would have been small — but on a low-traffic
  internal service, probe traffic can outnumber user traffic and pin the SLI near 100%
  through a total outage. Deciding what counts as a "valid request" is the highest-leverage
  decision in the whole spec.

---

## Later addition

[Module 21](../21-argocd-canary/README.md) reuses this service as its canary
subject, so `app/src/main.go` gained environment-variable configuration
(`BASELINE_ERROR_RATE`, `BASELINE_SLOW_RATE`, `APP_VERSION`) plus an
`app_build_info` gauge. **The defaults are unchanged** — they are the values all
the evidence above was captured with — so this lab reproduces identically. The
env vars only let a deliberately regressed build be shipped as an image.

---

## Runbook

Alert `SLODemoAvailabilityFastBurn` firing:

1. **Confirm it is real, not a traffic artifact.** Check request rate — a ratio computed
   over a handful of requests is noise.
   ```bash
   ./loadgen/chaos.sh status
   ```
2. **Scope it.** Is one pod failing or all of them?
   ```
   sum by (pod) (rate(http_requests_total{job="slo-demo",path="/api",status=~"5.."}[1m]))
     / sum by (pod) (rate(http_requests_total{job="slo-demo",path="/api"}[1m]))
   ```
   One pod → `kubectl delete pod`. All pods → look at the last deploy.
3. **Check budget left** to decide between rollback and a forward fix:
   ```
   slo:availability_error_budget_remaining:ratio6h
   ```
   Below 0.25, stop shipping and roll back.
4. **Verify recovery on the 5m window, not the 1h window** — the 1h window stays elevated
   for up to an hour after a real fix. Do not keep rolling things back because a long
   window has not caught up yet.

---

## Reproduce

```bash
kind create cluster --config cluster/kind-config.yaml
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace --values monitoring/kube-prom-stack-values.yaml --wait

docker build -t slo-demo:v1 ./app
kind load docker-image slo-demo:v1 --name slo-lab

kubectl create namespace slo-demo
kubectl apply -f app/ -f monitoring/servicemonitor.yaml -f loadgen/loadgen.yaml
kubectl apply -f slo/

./monitoring/import-dashboard.sh     # Grafana dashboard
./evidence/run-experiment.sh         # full incident + evidence capture
./evidence/render-timeline.sh        # ASCII chart from Prometheus
```

Teardown: `kind delete cluster --name slo-lab`
