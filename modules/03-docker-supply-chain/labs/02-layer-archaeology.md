# Lab 03.02 — Layer archaeology

**CORE · 40 min**

## Context

"Put COPY last" is a rule people repeat without understanding. This lab replaces
the rule with the mechanism, so you can reason about cases the rule does not
cover.

## The problem

### Part 1 — build the slow version deliberately

```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 go build -o /out/pulse-api .
```

Build it, then change one line in `main.go` and rebuild. Time both.

```bash
docker build -t slow -f Dockerfile.slow platform/services/pulse-api
sed -i 's/pulse-api listening/pulse-api now listening/' platform/services/pulse-api/main.go
time docker build -t slow -f Dockerfile.slow platform/services/pulse-api
```

### Part 2 — inspect what actually happened

```bash
docker history slow --no-trunc --format '{{.CreatedBy}}\t{{.Size}}'
docker build --progress=plain -f Dockerfile.slow platform/services/pulse-api 2>&1 | grep -E 'CACHED|RUN'
```

Which layers were reused? Which were rebuilt? **Why exactly** — name the input
whose hash changed.

### Part 3 — fix it and measure

Reorder so a code change invalidates as few layers as possible. Measure again.
Record both timings.

### Part 4 — the case the rule does not cover

Now answer these in `NOTAS.md`:

1. You add `COPY --chmod=755 script.sh /usr/local/bin/` early in the file. A
   colleague changes the file's **modification time** but not its content. Does
   the cache invalidate? Why?
2. Your Dockerfile has `RUN apt-get update && apt-get install -y curl`. The layer
   is cached from three weeks ago. What is wrong with that, and what is the fix
   that is *not* "disable the cache"?
3. `docker build --no-cache` versus `--pull`. What does each actually do?
4. Two developers build the same commit and get different image digests. Give
   three plausible causes.

## Expected outcome

Before/after timings, and the four questions answered.

## Staged hints

<details><summary>Hint 1 — what goes into a layer's cache key</summary>

For `RUN`, the instruction string itself plus the parent layer's ID. For `COPY`
and `ADD`, a checksum of the **file contents** plus metadata — which is why
question 1 has a more interesting answer than it looks.
</details>

<details><summary>Hint 2 — question 2</summary>

The cached layer pins a package index from three weeks ago, so you install
whatever versions were current then, including any since-patched CVEs. The fix is
not disabling the cache; it is either pinning versions explicitly so the build is
honest about what it installs, or invalidating that layer on a schedule via a
build argument.
</details>

## Why this lab exists

Module 09 makes CI build these images on every push. A 90-second rebuild that
could be 5 seconds, multiplied by every commit, is the difference between a
pipeline people wait for and one they work around.
