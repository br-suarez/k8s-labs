# SLO Specification — `slo-demo`

Service: `slo-demo` (HTTP API, 3 replicas, namespace `slo-demo`)
Owner: Platform / SRE
Version: 1.0

---

## 1. What the user actually cares about

Before writing a single query: the users of this service issue requests to `/api`
and expect them to **succeed** and to **come back quickly**. That gives two SLIs.
Everything else the service emits — CPU, memory, pod restarts, goroutine count —
is a *cause*, not a *symptom*, and does not belong in an SLO.

Two rules were applied when picking the signals:

- **Measure at the point closest to the user.** These SLIs are computed from the
  server's own request counters. In a real deployment they would ideally come
  from the load balancer or gateway, because a request that never reaches the
  pod is invisible to the pod but very visible to the user.
- **Exclude non-user traffic.** `/healthz` is scraped by kubelet probes every few
  seconds and is deliberately *not* instrumented. Folding thousands of always-200
  probe requests into the SLI would dilute the ratio and mask real user-facing
  failures.

---

## 2. SLI definitions

### SLI 1 — Availability

> The proportion of valid `/api` requests served without a server error.

```
           count of /api requests with status not in 5xx
SLI_avail = ---------------------------------------------
                 count of all /api requests
```

4xx responses count as **successes**. A `400 Bad Request` means the client sent
something invalid — the service behaved correctly. Counting 4xx as failures makes
the SLO burn every time a scanner probes a bad URL.

### SLI 2 — Latency

> The proportion of valid `/api` requests served faster than 300 ms.

```
           count of /api requests with duration <= 300ms
SLI_lat = ----------------------------------------------
                count of all /api requests
```

This is a **threshold ratio**, not an average or a percentile of a percentile.
`histogram_quantile` over a p99 cannot be averaged across windows or instances
without lying; a bucket ratio can. That is why the histogram in `app/src/main.go`
has `0.3` as an exact bucket boundary — the SLI is then a direct read of
`http_request_duration_seconds_bucket{le="0.3"}`, with zero interpolation.

---

## 3. SLO targets

| # | SLI | Target | Compliance window |
|---|-----|--------|-------------------|
| 1 | Availability | **99.5%** of `/api` requests non-5xx | 28 days rolling |
| 2 | Latency | **99%** of `/api` requests under 300 ms | 28 days rolling |

28 days rolling, not calendar-month: a rolling window has no artificial "budget
resets on the 1st" cliff that tempts teams to ship risky changes on the 30th.

Targets are deliberately **not** 99.99%. The service has no redundancy across
regions and rides on a single kind cluster; promising four nines would be a
number nobody could honour, and an SLO nobody believes is worse than no SLO.

---

## 4. Error budget

Error budget = `1 - SLO`, expressed as allowed bad events over the window.

28 days = `28 x 24 x 60` = **40,320 minutes**.

| SLO | Budget (ratio) | Budget as full-outage time / 28d |
|-----|----------------|----------------------------------|
| Availability 99.5% | 0.5% | 40,320 x 0.005 = **201.6 minutes** (~3h 22m) |
| Latency 99% | 1.0% | 40,320 x 0.010 = **403.2 minutes** (~6h 43m) |

"201.6 minutes" is the *equivalent* of a total outage. In practice the budget is
spent as partial failure: 10% of requests failing for 20 hours consumes the same
budget as everything failing for 2 hours.

**What the budget is for:** it is a spending allowance, not a target to protect.
A team that ends the window with 100% of its budget unspent was too conservative
— it under-shipped. The policy attached to this SLO:

- **Budget remaining > 25%** → ship freely.
- **Budget remaining < 25%** → non-critical releases pause; reliability work is
  prioritised over features until the window recovers.
- **Budget exhausted** → change freeze except for fixes that restore the SLO.

---

## 5. Burn rate

Burn rate = how many times faster than "even pace" the budget is being consumed.
Burn rate `1` spends the entire budget exactly at the end of 28 days.
Burn rate `14.4` spends the whole 28-day budget in under 2 days.

```
                observed error ratio in window
burn_rate = ---------------------------------------
                    (1 - SLO)
```

For the 99.5% availability SLO, a 3.5% error rate over an hour is a burn rate of
`0.035 / 0.005` = **7x**.

### Why alert on burn rate instead of on the error ratio

Alerting on "error rate > 1%" is either too noisy or too slow, and its urgency
has no relationship to how much budget is actually left. Burn-rate alerting ties
the page directly to the thing that matters: *how fast are we running out?*

### Multi-window, multi-burn-rate

Each alert requires a **long window** (is this significant?) **and** a **short
window** (is it still happening right now?). The short window is what stops an
alert from staying firing for an hour after the incident is already resolved.

Windows follow the Google SRE Workbook table, calibrated for a 28-day window:

| Severity | Long window | Short window | Burn rate | Budget consumed if sustained | Budget gone in |
|----------|-------------|--------------|-----------|------------------------------|----------------|
| **Page** | 1 hour | 5 min | 14.4x | ~2% | ~2 days |
| **Page** | 6 hours | 30 min | 6x | ~5% | ~4.7 days |
| **Ticket** | 1 day | 2 hours | 3x | ~10% | ~9.3 days |
| **Ticket** | 3 days | 6 hours | 1x | ~10% | 28 days |

Concretely, for the 99.5% SLO the fast-burn page fires when the error ratio
exceeds `14.4 x 0.005` = **7.2%** over both the last hour and the last 5 minutes.

Two severities, deliberately: a 14.4x burn deserves waking someone up, a 1x burn
does not. Paging on a slow burn is how on-call rotations get destroyed.

---

## 6. What is explicitly out of scope

- **Pod restarts, CPU, memory** — causes, not symptoms. They belong on a
  troubleshooting dashboard, not in an SLO or a paging alert.
- **`/healthz` and `/chaos`** — not user traffic.
- **Scrape gaps** — if Prometheus stops scraping, the SLI goes to `NaN` rather
  than to 0. Absence of data is not evidence of failure, and an alert that fires
  on missing data is monitoring the monitoring, which is a separate concern
  (covered by the stack's own `Watchdog` / `PrometheusTargetMissing` rules).
