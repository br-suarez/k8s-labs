# Lab 02.02 — TLS termination and what it costs

**CORE · 45 min**

## Context

Terminating TLS is three lines of config. Knowing what those three lines cost,
and what the backend now needs to be told, is the actual skill.

## The problem

### Part 1 — a local CA

Do not use a self-signed certificate. Create a real CA and issue a certificate
from it, because that is what every production setup actually looks like and the
trust chain is the part that breaks.

```bash
mkdir -p modules/02-nginx-edge/lab/tls && cd $_

# CA
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout ca.key -out ca.crt -subj "/CN=Pulse Local CA"

# Server key and CSR
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr \
  -subj "/CN=pulse.local"

# Sign it — note the SAN, without which modern clients reject it outright
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256 \
  -extfile <(printf "subjectAltName=DNS:pulse.local,DNS:localhost,IP:127.0.0.1")
```

### Part 2 — terminate

Extend your config from lab 01:

1. Listen on 8443 with TLS.
2. Listen on 8081 and redirect everything to HTTPS with a **301**.
3. Tell the backend the original scheme was HTTPS.
4. Enable HTTP/2.
5. Restrict to TLS 1.2 and 1.3 only.

Verify the chain properly:

```bash
curl --cacert modules/02-nginx-edge/lab/tls/ca.crt \
  --resolve pulse.local:8443:127.0.0.1 https://pulse.local:8443/api/checks
```

Using `-k` defeats the purpose of the lab — it skips exactly the validation you
are trying to learn.

### Part 3 — measure the cost

```bash
# Handshake time, TLS 1.3 vs 1.2
for v in 1.2 1.3; do
  echo -n "TLS $v: "
  curl --cacert .../ca.crt --resolve pulse.local:8443:127.0.0.1 \
    --tlsv$v --tls-max $v -o /dev/null -s \
    -w '%{time_appconnect}s\n' https://pulse.local:8443/
done
```

Then enable session resumption and measure again. Record all four numbers in
`NOTAS.md`.

## Expected outcome

- HTTPS works with full chain validation, no `-k`
- HTTP redirects with 301
- Backend receives `X-Forwarded-Proto: https`
- Four handshake measurements recorded

## Questions to answer in NOTAS.md

1. Why does TLS 1.3 need fewer round trips than 1.2?
2. What breaks in an application if you terminate TLS and **do not** send
   `X-Forwarded-Proto`?
3. You used a 301 for the redirect. When would 302 or 308 be correct instead?

## Staged hints

<details><summary>Hint 1 — certificate rejected despite the CA</summary>

Modern clients ignore `CN` and require a Subject Alternative Name. The `-extfile`
line above supplies it. If you omitted it, the error mentions the subject
alternative name directly.
</details>

<details><summary>Hint 2 — question 2</summary>

The application sees a plain HTTP request. If it generates absolute URLs, it
emits `http://` links. If it also redirects HTTP to HTTPS itself, you get an
infinite redirect loop — a classic and very confusing outage, because each
component is behaving correctly in isolation.
</details>
