# Lab 01.01 — The script that lies

**CORE · 45 min**

## Context

A script that exits 0 when it failed is worse than one that crashes. The crash
gets fixed; the lie gets trusted for eight months and then costs you an incident.

## The problem

Create `lab/deploy-check.sh` that reports whether a deployment is healthy. It
must:

1. Take a service URL and an expected version string.
2. Fetch `$URL/healthz` and require HTTP 200.
3. Fetch `$URL/api/checks` and require valid JSON.
4. Confirm the reported version matches the expected one.
5. Retry each check up to 3 times with backoff, because a single failed request
   is not a failed deployment.
6. Exit 0 only if **everything** passed. Exit 1 on any failure, with a message
   naming exactly which check failed and what it saw.
7. Clean up temporary files on success, on failure, and on Ctrl-C.
8. Pass `shellcheck` with zero warnings.

Test it against the real Pulse API:

```bash
make build
./bin/pulse-api &
./lab/deploy-check.sh http://localhost:8080 v1
```

## Now break it deliberately

Prove your script does not lie. Each of these must produce a **specific** failure
message, not a generic one:

| Break | Expected message |
|---|---|
| Stop the API entirely | connection refused, named check |
| Point at a URL returning HTML instead of JSON | invalid JSON, named check |
| `kill -STOP` the API (hangs, never responds) | timeout, not an infinite wait |
| Expect `v2` when it reports `v1` | version mismatch, both values shown |

That third one is the one people miss. A script with no timeout does not fail —
it hangs, and your CI job runs for six hours.

## Expected outcome

Four distinct, accurate failure messages, and a clean exit 0 on the happy path.

## Verification

```bash
shellcheck lab/deploy-check.sh && echo clean
./lab/deploy-check.sh http://localhost:8080 v1 && echo "exit 0 as expected"
./lab/deploy-check.sh http://localhost:9999 v1 || echo "exit non-zero as expected"
```

## Staged hints

<details><summary>Hint 1 — timeouts</summary>

`curl` waits forever by default. `--max-time` bounds the whole request,
`--connect-timeout` only the handshake. You want both, and you want the values to
be different.
</details>

<details><summary>Hint 2 — cleanup on every path</summary>

`trap 'rm -rf "$tmp"' EXIT` fires on normal exit, on `set -e` abort, and on
signals. Set it **immediately** after creating the temp dir, not at the end of
the script — a failure between creation and trap leaks.
</details>

<details><summary>Hint 3 — retry with backoff</summary>

A `for` loop with `sleep $((2 ** attempt))`. The subtlety: on the final attempt
you must preserve the actual error, not just report "retries exhausted". The
message that says *what went wrong on the last try* is the one that saves time at
3am.
</details>

## Why this lab exists

You write this pattern again in module 09 as a CI gate and in module 11 as the
canary analysis. Getting it right once here means you are not debugging it under
a rollback later.
