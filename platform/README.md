# Pulse — the capstone platform

An endpoint health monitoring service. You register URLs to watch; workers probe
them on a schedule and record the results.

It is deliberately an SRE tool. Every observability lesson in this track lands
better when the thing being observed is itself a monitoring system, and the
failure modes you have to reason about — a queue backing up, a probe timing out,
a result write failing — are the ones you actually meet on call.

## Services

| Service | Language | Port | Role |
|---|---|---|---|
| `pulse-api` | Go | 8080 | Check registry and results API |
| `pulse-worker` | Go | 8081 | Probes targets, reports results |
| `pulse-web` | static | — | Dashboard, served by the edge |
| `postgres` | — | 5432 | Result store *(added module 06)* |
| `redis` | — | 6379 | Job queue *(added module 06)* |

## Design decisions worth knowing

**The application code is given to you.** You are learning infrastructure, not Go.
But you will modify it — module 08 has you instrument it by hand, and several
break-fix scenarios are triggered by changing it.

**It starts with zero external dependencies.** Module 01 builds and runs both
services with nothing but the Go standard library: the store is in memory and the
metrics endpoint is hand-written. That is not laziness, it is sequencing — you
cannot depend on Postgres in module 01 because Postgres arrives in module 06.

**Every replacement is deliberate.** The hand-rolled metrics exporter exists so
that when module 07 swaps in the official Prometheus client, you already know
exactly what it is generating and why the histogram buckets are cumulative.

| Piece | Module 01 | Replaced in |
|---|---|---|
| Storage | in-memory map | 06 (Postgres) |
| Queue | buffered channel | 06 (Redis) |
| Metrics | hand-written text format | 07 (Prometheus client) |
| Tracing | none | 08 (OpenTelemetry SDK) |
| Edge | none | 02 (NGINX) → 05 (Gateway API) |

## The signals it emits

| Metric | Type | Why it exists |
|---|---|---|
| `pulse_http_requests_total` | counter | Rate and errors — two thirds of RED |
| `pulse_http_request_duration_seconds` | histogram | Duration, and the source of the module 07 latency SLI |
| `pulse_worker_queue_depth` | gauge | **Saturation.** The signal the SLO is built on |
| `pulse_worker_queue_dropped_total` | counter | Backpressure made visible instead of silent |
| `pulse_worker_probe_failures_total` | counter | Distinguishes "Pulse is broken" from "the target is down" |

That last distinction is the whole reason the platform is a monitoring tool. A
naive SLO on Pulse would page you every time a *monitored* endpoint went down,
which is precisely the alert-fatigue failure mode module 07 teaches you to avoid.

## Running it locally

```bash
make build
./bin/pulse-api &
PULSE_API_URL=http://localhost:8080 ./bin/pulse-worker &

curl -X POST localhost:8080/api/checks \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com","interval_seconds":30}'

curl -s localhost:8080/api/results | jq
curl -s localhost:8081/metrics | grep queue_depth
```

## Configuration

Both services are configured entirely by environment variable — no config files,
because module 04 mounts these as a ConfigMap and module 10 templates them per
overlay.

| Variable | Service | Default | Notes |
|---|---|---|---|
| `PORT` | both | 8080 / 8081 | |
| `PULSE_API_URL` | worker | `http://localhost:8080` | Becomes a Service DNS name in module 04 |
| `WORKER_CONCURRENCY` | worker | `4` | Break-fix material: too low and the queue saturates |
| `QUEUE_SIZE` | worker | `64` | Bounded on purpose |
| `SCHEDULE_INTERVAL_SECONDS` | worker | `15` | |

## Layout

```
platform/
├── services/       # application code
├── deploy/
│   └── clusters/   # kind profiles: lite, standard, ha
└── scripts/
    └── verify.sh   # the harness every module extends
```
