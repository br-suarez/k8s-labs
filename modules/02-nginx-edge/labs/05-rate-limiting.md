# Lab 02.05 — Rate limiting under load

**EXTEND · 40 min**

> Skip if behind schedule. Worth returning to: this is how you protect a backend
> you cannot scale quickly.

## Context

Rate limiting is easy to turn on and easy to get wrong in a way that only shows
up under real traffic — when it starts rejecting legitimate users.

## The problem

### Part 1 — limit by rate

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
```

Apply it to `/api/`. Then test with `burst` and `nodelay` in three
configurations:

| Config | Behaviour to observe |
|---|---|
| `limit_req zone=api;` | Strict — what happens to request 11 in a second? |
| `limit_req zone=api burst=20;` | Queued — measure the added latency |
| `limit_req zone=api burst=20 nodelay;` | Immediate — what is the trade-off? |

Generate load and record, for each: requests accepted, rejected, and the p99
latency of the accepted ones.

```bash
for i in $(seq 100); do
  curl -s -o /dev/null -w '%{http_code} %{time_total}\n' -k \
    https://localhost:8443/api/checks &
done | sort | uniq -c
wait
```

### Part 2 — the trap

`$binary_remote_addr` is the client IP. Your edge sits behind a load balancer in
production, so every request arrives from the same address.

1. Demonstrate the failure: put a second NGINX in front and show the rate limit
   now applies to *all* traffic collectively.
2. Fix it with `set_real_ip_from` and `real_ip_header`.
3. Then explain the security problem you just created, and how you bound it.

### Part 3 — degrade honestly

Default rejection is a bare 503. Configure:

- `limit_req_status 429` — the correct code
- A `Retry-After` header
- A JSON error body, since clients of `/api/` expect JSON

## Expected outcome

A table in `NOTAS.md` with the three configurations measured, plus a working
`X-Forwarded-For` chain with an explicit trusted-proxy list.

## Staged hints

<details><summary>Hint 1 — burst vs nodelay</summary>

`burst=20` queues up to 20 excess requests and releases them at the configured
rate — so they succeed, slowly. `nodelay` serves the whole burst immediately and
then enforces the rate. Queuing protects the backend but adds latency that can
exceed a client's timeout, which turns a rate limit into an outage from the
client's point of view.
</details>

<details><summary>Hint 2 — the security problem in part 2</summary>

`real_ip_header X-Forwarded-For` makes NGINX trust a client-supplied header. Any
client can then set it to a random address and get a fresh rate limit bucket per
request. `set_real_ip_from` is what bounds the trust — it must list only your
actual proxies, never `0.0.0.0/0`.
</details>
