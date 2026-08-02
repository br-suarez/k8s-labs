# Lab 07.03 — Whose failure is it?

**CORE · 50 min.** The conceptual centre of this module.

## Context

Pulse monitors other people's endpoints. A naive availability SLI pages you every
time a *monitored* endpoint goes down — which is not your outage, happens
constantly, and will get your alerts muted within a week.

## The problem

### Part 1 — build the wrong one, and feel it

Define the obvious SLI:

```promql
sum(rate(pulse_worker_probes_total{result="success"}[5m]))
/ sum(rate(pulse_worker_probes_total[5m]))
```

Set a 99% SLO and an alert. Now add a check pointing at something guaranteed to
fail:

```bash
curl -XPOST .../api/checks -d '{"url":"https://this-does-not-resolve.invalid"}'
```

Watch your SLO burn. **You did nothing wrong and you are being paged.**

Record how many broken customer endpoints it takes to exhaust the budget. On a
realistic account that number is small, which is the point.

### Part 2 — separate the two questions

Write down the two distinct questions:

- "Is Pulse working?" → **your** SLI
- "Are the monitored endpoints up?" → the **product**, not your reliability

Then define the real SLIs. Suggested starting points — refine them:

| SLI | Question it answers | Sketch |
|---|---|---|
| Probe freshness | Did we probe each check within its interval? | staleness of `pulse_probe_last_success_timestamp` |
| Scheduling | Did we schedule everything we should have? | `queue_dropped_total` relative to scheduled |
| API availability | Does the API answer? | non-5xx over total on `/api/*` |
| API latency | Fast enough? | p99 under threshold |
| Result durability | Did results get written? | writes attempted vs persisted |

For each, write: the exact PromQL, the target, the measurement window, and — most
importantly — **what user pain it corresponds to**.

An SLI that does not map to something a user notices is a metric, not an SLI.

### Part 3 — the failures that ARE yours

Some probe failures genuinely are your fault. Distinguish them:

| Symptom | Whose |
|---|---|
| Target returns 500 | Theirs |
| DNS for the target does not resolve | Theirs |
| Probe never ran — queue was full | **Yours** |
| Probe timed out because your worker was starved | **Yours** |
| Result computed but never written to the database | **Yours** |

Instrument the distinction. `pulse-worker` must be able to say *why* a probe
failed, with a bounded label set. Add `reason` with a fixed, enumerated set of
values — and be able to state the maximum cardinality before you add it.

### Part 4 — write it down

Create `platform/SLO.md`: each SLI, its PromQL, target, window, rationale, and
the user pain it maps to. Include what you explicitly chose **not** to measure
and why.

## Expected outcome

A demonstrated false-page from the naive SLI, four to five real SLIs as code, a
`reason` label with bounded cardinality, and `SLO.md`.

## Staged hints

<details><summary>Hint 1 — freshness as an SLI</summary>

The strongest Pulse SLI is not a success rate at all. It is: "the proportion of
checks whose last probe attempt is within their configured interval." That is
true whether or not the target is up, because it measures whether *you did your
job*. Attempting and recording a failure is success, for Pulse.
</details>

<details><summary>Hint 2 — bounding the reason label</summary>

Enumerate in code: `timeout`, `dns`, `connection_refused`, `tls`, `http_error`,
`queue_full`, `internal`. Seven values, fixed at compile time. Anything not
matching maps to `other`. **Never** derive the label from an error string —
error strings contain URLs, IPs and ports, and that is the break-fix.
</details>

## Why this lab exists

Module 20 in `archive/sre-track/` built burn-rate alerting on an SLI that was
given to you. This lab is the harder half: deciding what to measure when the
obvious answer is wrong.
