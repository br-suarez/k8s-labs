# Lab 02.01 — Reverse proxy from an empty file

**CORE · 50 min**

## Context

You have two backends: a static dashboard and a JSON API. They need to look like
one origin to the browser. This is the most common piece of infrastructure in
existence, and most engineers have only ever edited someone else's version of it.

## The problem

Start Pulse without any edge:

```bash
make build
./bin/pulse-api &                    # :8080
python3 -m http.server 3000 -d platform/services/pulse-web &   # :3000
```

Now write `modules/02-nginx-edge/lab/nginx.conf` **from an empty file** that:

1. Listens on 8081.
2. Routes `/` to the static server on 3000.
3. Routes `/api/` to pulse-api on 8080, preserving the `/api` prefix — the Go
   service registers its handlers at `/api/checks`, so getting the trailing
   slash wrong here produces a 404 and teaches the lesson immediately.
4. Passes the client's real IP and original scheme upstream.
5. Sets explicit connect, send and read timeouts. Do not accept the defaults —
   look up what they are and decide whether you want them.
6. Uses a keepalive connection pool to the API upstream **that actually works**.
7. Logs `$request_time` and `$upstream_response_time` as separate fields.

Run it:

```bash
nginx -c "$PWD/modules/02-nginx-edge/lab/nginx.conf" -t   # validate first
nginx -c "$PWD/modules/02-nginx-edge/lab/nginx.conf"
```

## Expected outcome

```bash
curl -s localhost:8081/ | head -3                    # the dashboard HTML
curl -s localhost:8081/api/checks                    # [] from the API
curl -s -XPOST localhost:8081/api/checks \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com"}'                 # 201
```

And in the access log, two distinct timing fields.

## Prove the keepalive works

This is requirement 6, and it is the one people get wrong silently.

```bash
# Before: count established connections to the upstream
ss -tan dst :8080 | wc -l

# Hammer it
for i in $(seq 200); do curl -s -o /dev/null localhost:8081/api/checks; done

# After: with keepalive working, this stays small.
# Without it, you will see a pile of TIME_WAIT.
ss -tan dst :8080 state time-wait | wc -l
```

If that last number is in the hundreds, requirement 6 is not met, no matter what
your `upstream` block says.

## Staged hints

<details><summary>Hint 1 — the /api prefix</summary>

`location /api/ { proxy_pass http://backend/; }` strips `/api`. `proxy_pass
http://backend;` (no trailing slash) passes the full URI. You want the second.
Test both and watch the 404 appear — this is worth doing wrong once deliberately.
</details>

<details><summary>Hint 2 — keepalive needs three things</summary>

`keepalive N` in the `upstream` block is necessary but not sufficient. NGINX
defaults to HTTP/1.0 upstream and sends `Connection: close`. You need
`proxy_http_version 1.1` and `proxy_set_header Connection ""` in the location
block. Without those two, the pool is configured and never used.
</details>

<details><summary>Hint 3 — timeouts</summary>

`proxy_connect_timeout` (default 60s), `proxy_send_timeout` (60s),
`proxy_read_timeout` (60s). Sixty seconds is almost never what you want at the
edge — decide your values and write down why. A connect timeout should be short
(the backend is local); a read timeout depends on your slowest legitimate
endpoint.
</details>

## Cleanup

```bash
nginx -c "$PWD/modules/02-nginx-edge/lab/nginx.conf" -s stop
kill %1 %2 2>/dev/null
```
