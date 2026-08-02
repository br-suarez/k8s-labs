# Lab 01.03 — Build the platform harness

**CORE · 60 min**

## Context

This is the capstone layer for module 01, and the most reused thing you build in
the whole track. Sixteen modules extend it.

## The problem

### Part 1 — make the build real

Install Go, then confirm the platform builds:

```bash
make build
make vet
make test
```

Fix anything that fails. `make test` will report no test files — that is your
next task.

### Part 2 — write the first tests

Add `platform/services/pulse-api/main_test.go` covering:

1. `POST /api/checks` with a valid body returns 201 and a generated ID.
2. `POST /api/checks` with an empty URL returns 400.
3. `POST /api/checks` with no `interval_seconds` defaults it to 30.
4. `GET /readyz` returns 503 before startup completes and 200 after.
5. The metrics endpoint reports a counter that increments across two requests.

Use `httptest`. Do not start a real server on a real port — tests that bind ports
fail in CI the moment two run in parallel, and you will meet that in module 09.

### Part 3 — extend the harness

Add to [`platform/scripts/verify.sh`](../../../platform/scripts/verify.sh):

1. A `test` group running `go test ./...` for both services.
2. Make `group_build` fail if either binary exceeds 20 MB — a size budget you
   will be glad of in module 03.
3. Register both in `ALL_GROUPS`, cheapest first.

## Expected outcome

```bash
./platform/scripts/verify.sh
```

Everything passes except groups whose infrastructure does not exist yet, which
must **skip**, not fail. Getting that distinction right is the point: a harness
that fails on things that legitimately do not exist yet gets ignored, and an
ignored harness is worse than none.

## Verification

```bash
make lint && make verify
```

## Staged hints

<details><summary>Hint 1 — testing readiness</summary>

`/readyz` flips after a `time.Sleep` in a goroutine. Testing that with a real
sleep makes a slow, flaky test. Refactor so readiness is settable, then test both
states directly. **The fact that the code is hard to test is the code's problem,
not the test's** — that realisation is most of what this part teaches.
</details>

<details><summary>Hint 2 — binary size</summary>

`stat -c %s file` gives bytes. Strip debug info with
`go build -ldflags="-s -w"` and compare. Note the trade-off before you adopt it:
you just made production stack traces less useful. Write down which side you
chose and why.
</details>

## Why this lab exists

Module 09 wires this exact harness into CI. Module 11 uses it as the canary gate.
Module 16 runs it as the Game Day health check. Build it properly now.
