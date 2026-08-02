# Lab 03.01 — Multi-stage to distroless

**CORE · 45 min**

## Context

The image you build here is the one every later module deploys, signs and
verifies. Getting it right now saves work in modules 09, 11 and 12.

## The problem

Write `platform/services/pulse-api/Dockerfile` from an empty file. Requirements,
each verifiable:

| # | Requirement | How you will verify it |
|---|---|---|
| 1 | Final image under 25 MB | `docker images --format '{{.Size}}'` |
| 2 | Runs as non-root | `docker run --rm img id` — but see hint 1 |
| 3 | No shell, no package manager | try `docker run --rm img sh` and expect failure |
| 4 | Outbound HTTPS works | probe a real `https://` URL |
| 5 | Stops in under 2s on `docker stop` | `time docker stop` |
| 6 | Code change rebuilds in under 5s | `touch main.go && time docker build` |
| 7 | `HEALTHCHECK` targets readiness | `docker inspect --format '{{.State.Health.Status}}'` |

Then do the same for `pulse-worker`.

## Expected outcome

Both images built, all seven requirements verified with commands, and the numbers
recorded in `NOTAS.md`.

## Verification

```bash
docker build -t pulse-api:lab platform/services/pulse-api
docker images pulse-api:lab --format 'size: {{.Size}}'

# Requirement 4 — the one that catches people
docker run --rm -d --name t pulse-api:lab
docker run --rm --network container:t curlimages/curl:latest \
  -sf https://example.com > /dev/null && echo "outbound TLS ok"
docker rm -f t
```

## Staged hints

<details><summary>Hint 1 — verifying non-root without a shell</summary>

You cannot run `id` in an image with no shell or coreutils. Check it from
outside instead:

```bash
docker inspect pulse-api:lab --format '{{.Config.User}}'
docker run --rm -d --name t pulse-api:lab && docker top t
```

The fact that the obvious verification does not work **is** part of the lesson
about distroless.
</details>

<details><summary>Hint 2 — requirement 4</summary>

`distroless/static` has no CA bundle. Copy it from the build stage:
`COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/`. If you
skip this, everything looks fine until the service makes its first outbound TLS
call — which is exactly this module's break-fix.
</details>

<details><summary>Hint 3 — requirement 6</summary>

Order instructions from least to most volatile. `COPY go.mod go.sum ./` then
`RUN go mod download` then `COPY . .`. Pulse has no external dependencies yet, so
the win is small now and large in module 08 when the OTel SDK arrives — build the
habit before you need it.
</details>

<details><summary>Hint 4 — requirement 7</summary>

Distroless has no `curl` or `wget` for `HEALTHCHECK` to call. Options: add a
`-healthcheck` flag to the Go binary that makes the request itself, or drop
`HEALTHCHECK` and rely on Kubernetes probes from module 04. Both are defensible —
write down which you chose and why.
</details>

## Note

Requirement 4 has no hint above the fold on purpose. If you meet it without the
hint, you have internalised something most engineers learn the painful way.
