# Lab 01.04 — Signals and graceful shutdown

**EXTEND · 40 min**

> Skip if behind schedule — but module 03 assumes you did it, and module 11's
> canary depends on the behaviour it teaches.

## Context

Every Kubernetes deployment sends `SIGTERM` and waits. What your process does in
that window decides whether a rollout is invisible or drops requests.

## The problem

### Part 1 — observe correct behaviour

`pulse-api` already handles `SIGTERM`. Prove it:

```bash
make build
./bin/pulse-api &
API_PID=$!

# Generate steady traffic
while :; do curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/healthz; sleep 0.1; done &
LOAD_PID=$!

sleep 2
kill -TERM $API_PID
```

Record: how many requests failed? What did the logs say? How long between signal
and exit?

### Part 2 — break it

Comment out the `signal.Notify` block and rebuild. Repeat part 1.

Now the process dies immediately on `SIGTERM` with no drain. Measure the
difference in failed requests. **Write down the actual numbers** — this is the
evidence you cite when someone asks why graceful shutdown matters.

### Part 3 — the PID 1 trap

This is the one that bites in containers.

```bash
docker run --rm -d --name sig-test alpine sh -c 'sleep 300'
time docker stop sig-test
```

It takes 10 seconds. `docker stop` sends `SIGTERM`, waits, then `SIGKILL`s.
Now:

```bash
docker run --rm -d --name sig-test2 alpine sleep 300
time docker stop sig-test2
```

Explain the difference. Then explain which of the two your Dockerfile produces if
you write `CMD ./pulse-api` versus `CMD ["./pulse-api"]`.

## Expected outcome

In `NOTAS.md`:

- Failed requests with and without graceful shutdown
- Why PID 1 does not get default signal handling
- The exact Dockerfile line that avoids the problem

## Verification

```bash
# Should exit within 1s, not hang for the grace period
./bin/pulse-api & sleep 1; time kill -TERM $!
```

## Staged hints

<details><summary>Hint 1 — PID 1</summary>

The kernel treats PID 1 specially: signals without an explicit handler are **not**
delivered with their default action. A `sleep` running as PID 1 with no handler
simply ignores `SIGTERM`. The shell form of `CMD` wraps your process in
`/bin/sh -c`, making the *shell* PID 1 — and the shell does not forward signals
to its child.
</details>

<details><summary>Hint 2 — measuring failed requests</summary>

Count non-200 responses in the load loop's output. Curl's `%{http_code}` is `000`
on connection failure, which is exactly what you want to count.
</details>

## Why this lab exists

`terminationGracePeriodSeconds` in module 04, connection draining in module 05,
and canary step timing in module 11 are all downstream of this. It is also one of
the most common real-world causes of "we get 502s during every deploy".
