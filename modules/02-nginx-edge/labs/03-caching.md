# Lab 02.03 — Caching, and the request you must never cache

**CORE · 50 min**

## Context

Caching is the highest-leverage thing an edge does and the easiest place to cause
a data breach. This lab does both halves.

## The problem

### Part 1 — make it fast

Add caching for `/api/results`, which is read-heavy and tolerates staleness:

1. `proxy_cache_path` with a sensible zone size.
2. Cache 200 responses for 5 seconds.
3. Expose `$upstream_cache_status` as a response header.
4. Enable `proxy_cache_lock` so a cache miss does not stampede the backend.

Prove it works:

```bash
# Seed some data
for i in $(seq 5); do
  curl -s -XPOST localhost:8443/api/checks -k \
    -H 'content-type: application/json' \
    -d "{\"url\":\"https://example.com/$i\"}" > /dev/null
done

# First request MISS, subsequent HIT
for i in $(seq 5); do
  curl -sI -k https://localhost:8443/api/results | grep -i x-cache-status
  sleep 1
done
```

### Part 2 — measure the benefit

Compare backend load with and without the cache:

```bash
# Watch the API's own request counter
curl -s localhost:8080/metrics | grep pulse_http_requests_total

# 200 requests through the edge
for i in $(seq 200); do curl -s -o /dev/null -k https://localhost:8443/api/results; done

# How many actually reached the backend?
curl -s localhost:8080/metrics | grep pulse_http_requests_total
```

Record the ratio. That number is the entire argument for the cache.

### Part 3 — the dangerous one

Now add a per-user endpoint. Pulse does not have authentication yet, so simulate
it: make the API vary its response on a header.

**Question, before you write any config:** if you cache a response that differs
per user with the cache key you wrote in part 1, what happens?

Construct the failure deliberately. Two "users", same URL, different headers, and
show one receiving the other's data. Capture the output — you are reproducing a
real class of production data breach in a controlled setting.

Then fix it, two ways:

- **A:** include the identity in `proxy_cache_key`
- **B:** `proxy_no_cache` + `proxy_cache_bypass` on the auth header

Implement both. Measure the hit ratio under each. Choose one for Pulse and write
down why in `NOTAS.md`.

## Expected outcome

- Documented hit ratio and backend load reduction
- A reproduction of the cross-user leak, with output
- Both fixes implemented, one chosen and defended

## Staged hints

<details><summary>Hint 1 — no-cache alone is not enough</summary>

`proxy_no_cache` stops NGINX **storing** the response. It does not stop it
**serving** an entry that is already stored. You need `proxy_cache_bypass` with
the same condition, or a poisoned entry keeps being served until it expires.
</details>

<details><summary>Hint 2 — what belongs in a cache key</summary>

Everything the response varies on. If the backend sends `Vary: Accept-Encoding`,
NGINX handles that. If it varies on something NGINX cannot see — a session, a
tenant, a feature flag — you have to put it in the key yourself, or not cache
at all.
</details>

## Note

This lab is the setup for this module's break-fix. Do the lab first; the
break-fix asks you to diagnose the same class of bug from the symptom side,
without knowing where to look.
