# Lab 03.06 — Build reproducibility

**EXTEND · 40 min**

> Skip if behind schedule. Return to it before module 12, where signing an
> artifact you cannot independently rebuild is a much weaker guarantee.

## Context

If the same source produces a different image every time, a signature proves who
built it and nothing about what they built.

## The problem

### Part 1 — measure the damage

```bash
docker build --no-cache -t repro-1 platform/services/pulse-api
docker build --no-cache -t repro-2 platform/services/pulse-api

docker inspect repro-1 --format '{{.Id}}'
docker inspect repro-2 --format '{{.Id}}'
```

Different. Find out **why**, specifically:

```bash
docker save repro-1 -o /tmp/r1.tar && mkdir -p /tmp/r1 && tar -xf /tmp/r1.tar -C /tmp/r1
docker save repro-2 -o /tmp/r2.tar && mkdir -p /tmp/r2 && tar -xf /tmp/r2.tar -C /tmp/r2
diff -r /tmp/r1 /tmp/r2 | head -20
```

### Part 2 — make the binary reproducible first

The Go binary is the easier half:

```dockerfile
RUN CGO_ENABLED=0 GOFLAGS=-trimpath \
    go build -ldflags="-s -w -buildid=" -o /out/pulse-api .
```

Verify:

```bash
docker build --no-cache -t bin-1 platform/services/pulse-api
docker build --no-cache -t bin-2 platform/services/pulse-api
docker run --rm bin-1 -version-sha 2>/dev/null || \
  for i in 1 2; do docker create --name c$i bin-$i && \
    docker cp c$i:/app/pulse-api /tmp/bin-$i && docker rm c$i; done
sha256sum /tmp/bin-1 /tmp/bin-2
```

### Part 3 — the image is harder

Even with an identical binary, image digests differ because of layer timestamps.

```dockerfile
ARG SOURCE_DATE_EPOCH
```

Build with `--build-arg SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)` and BuildKit's
`rewrite-timestamp` output option. Get as far as you can, then write down in
`NOTAS.md` exactly which sources of non-determinism you eliminated and which you
could not.

## Expected outcome

Identical binary hashes across two clean builds. Image-level reproducibility is a
stretch goal — **partial success with an honest account of what remains is the
expected result**, not a failure.

## Questions

1. Why does `-trimpath` matter? What was leaking without it?
2. Why does `-buildid=` matter?
3. If two builds of the same commit differ, what can a signature still prove?
4. What does SLSA level 3 require that this lab does not achieve?

## Staged hints

<details><summary>Hint 1 — question 1</summary>

Without `-trimpath`, the binary embeds absolute paths from the build machine's
filesystem. Two developers in different directories produce different binaries —
and those paths also leak your directory structure into a shipped artifact.
</details>

<details><summary>Hint 2 — question 3</summary>

It proves the artifact was produced by a holder of that key and has not been
altered since. It does **not** prove the artifact corresponds to any particular
source. Closing that gap is what provenance attestation is for, and it is why
module 12 generates an SBOM and an attestation rather than only a signature.
</details>

## Cleanup

```bash
docker rmi -f repro-1 repro-2 bin-1 bin-2 2>/dev/null
rm -rf /tmp/r1 /tmp/r2 /tmp/r1.tar /tmp/r2.tar /tmp/bin-1 /tmp/bin-2
```
