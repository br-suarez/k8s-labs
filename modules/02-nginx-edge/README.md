# Module 02 — NGINX as Edge

**4 blocks.** Requires module 01.

You build the edge with NGINX here, operate it, and then **replace it with
Gateway API in module 05**. That sequence is deliberate: having built one, you
can argue about the other. Starting at Gateway API leaves you with nothing to
compare it to, and the exit criterion for this track is being able to defend a
decision against alternatives.

## Objectives

1. Configure NGINX as a reverse proxy in front of a multi-service application,
   from an empty config file.
2. Reason about caching correctly — what is safe to cache, what is catastrophic
   to cache, and how to prove which is happening.
3. Read an NGINX access log well enough to diagnose a latency problem.
4. Terminate TLS and know what your cipher and protocol choices cost.

## Exit criteria

- [ ] I can write an NGINX config that proxies two backends by path, terminates
      TLS, and caches safely — **without documentation open**.
- [ ] Given a 502, I can determine in under 5 minutes whether the cause is
      NGINX, the network, or the upstream, and name the log field that told me.
- [ ] I can explain `proxy_buffering` on vs off, and name a workload that breaks
      under each setting.
- [ ] I can defend NGINX against HAProxy and Envoy for this use case.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | [Repaso](./labs/00-repaso.md) (módulos 00–01) | CORE | 15 min |
| 01 | [Reverse proxy from an empty file](./labs/01-reverse-proxy.md) — and prove keepalive actually works | CORE | 50 min |
| 02 | [TLS termination](./labs/02-tls.md) with a local CA; measure the handshake, TLS 1.2 vs 1.3 | CORE | 45 min |
| 03 | [Caching](./labs/03-caching.md) — and the request you must never cache | CORE | 50 min |
| 04 | [Log forensics](./labs/04-log-forensics.md) — a real incident in a generated access log | CORE | 40 min |
| 05 | [Rate limiting under load](./labs/05-rate-limiting.md) | EXTEND | 40 min |
| 06 | [Buffering and streaming](./labs/06-buffering.md) | DEEP | 30 min |

## Capstone layer

Pulse gains a real edge. After this module:

```bash
curl -k https://localhost:8443/          # pulse-web dashboard
curl -k https://localhost:8443/api/checks # proxied to pulse-api
curl http://localhost:8080/              # redirects to HTTPS
```

The `nginx` group in `platform/scripts/verify.sh` goes green.

## Key distinction for this module

`$request_time` measures the whole client transaction including how slowly the
client reads the response. `$upstream_response_time` measures only your backend.
A rising `$request_time` with flat `$upstream_response_time` means slow clients
or a network problem — **not** a slow application. Getting this backwards sends
teams optimising a backend that was never the problem.

## Verification

```bash
./platform/scripts/verify.sh nginx
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
