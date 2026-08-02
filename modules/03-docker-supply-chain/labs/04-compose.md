# Lab 03.04 — Compose the stack

**CORE · 45 min**

## Context

This is the capstone layer for module 03: the whole platform running with one
command, with startup ordering that is actually correct rather than approximately
correct.

## The problem

Write `platform/deploy/compose.yaml` bringing up `pulse-api`, `pulse-worker` and
`pulse-web` behind the NGINX edge from module 02.

Requirements:

1. All four services, built from the Dockerfiles you wrote in lab 01.
2. `pulse-worker` must not start until `pulse-api` is **ready**, not merely
   started.
3. Health checks on every service that can have one.
4. Configuration by environment variable, no config files baked into images.
5. A named volume for NGINX's cache directory.
6. Resource limits on every service.
7. `docker compose up -d --wait` returns success only when everything is healthy.

## The distinction that matters

```yaml
depends_on:
  pulse-api:
    condition: service_started      # waits for the container to exist
```

versus

```yaml
depends_on:
  pulse-api:
    condition: service_healthy      # waits for the healthcheck to pass
```

`pulse-api` reports `/readyz` as 503 for its first two seconds. With
`service_started`, the worker starts immediately, its first `fetchChecks` call
fails, and it logs an error before recovering on the next tick. Not fatal here,
but it is exactly the same bug as a Kubernetes Deployment with no readiness
probe — which in module 04 *is* fatal, because a Service will route traffic to
a pod that is not ready.

Demonstrate both behaviours and capture the log difference.

## Expected outcome

```bash
docker compose -f platform/deploy/compose.yaml up -d --wait
./platform/scripts/verify.sh nginx
docker compose -f platform/deploy/compose.yaml logs pulse-worker | head -20
```

Clean startup with no error on the worker's first poll.

## Staged hints

<details><summary>Hint 1 — healthcheck on a distroless image</summary>

There is no `curl` inside. Options: a `-healthcheck` flag on the Go binary,
Compose's `test: ["CMD", "/app/pulse-api", "-healthcheck"]`, or move the check
outside the container entirely. Note that this same constraint reappears in
module 04, where Kubernetes probes solve it differently — the kubelet makes the
HTTP request itself, so nothing needs to exist inside the image.
</details>

<details><summary>Hint 2 — resource limits in Compose</summary>

`deploy.resources.limits` is honoured by `docker compose` v2 for `cpus` and
`memory`. Set them deliberately: this is your first chance to think about what
Pulse actually needs, and you will reuse those numbers as Kubernetes requests
and limits in module 04.
</details>

## Cleanup

```bash
docker compose -f platform/deploy/compose.yaml down -v
```

The `-v` matters: without it the NGINX cache volume survives, and a stale cache
across lab runs produces confusing results.
