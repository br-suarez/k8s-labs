# Lab 02.06 — Buffering and streaming

**DEEP · 30 min**

> Optional. Do it if you finish early or in a reserve week. It explains a class
> of bug that is baffling if you have never seen it.

## Context

`proxy_buffering on` is the default and it is usually right. When it is wrong,
the symptom is that a feature simply does not work, with no error anywhere.

## The problem

### Part 1 — build something that streams

Add a streaming endpoint to `pulse-api` that emits Server-Sent Events, one result
per second for 30 seconds:

```go
// GET /api/stream
w.Header().Set("Content-Type", "text/event-stream")
w.Header().Set("Cache-Control", "no-cache")
flusher, ok := w.(http.Flusher)
if !ok {
    http.Error(w, "streaming unsupported", http.StatusInternalServerError)
    return
}
for i := 0; i < 30; i++ {
    fmt.Fprintf(w, "data: {\"tick\":%d}\n\n", i)
    flusher.Flush()
    time.Sleep(time.Second)
}
```

### Part 2 — watch it fail through the proxy

```bash
# Direct — events arrive one per second
curl -N localhost:8080/api/stream

# Through NGINX with default buffering — nothing for 30s, then everything
curl -N -k https://localhost:8443/api/stream
```

Confirm the behaviour before changing anything. This is the bug as a user
experiences it, and notice there is no error: it is not broken, it is buffered.

### Part 3 — fix it, narrowly

```nginx
location /api/stream {
    proxy_pass http://pulse_api;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 1h;
    chunked_transfer_encoding on;
}
```

Do it in its own `location`, not globally. Then answer in `NOTAS.md`:

1. Why must `proxy_cache` be off too, not just buffering?
2. Why does `proxy_read_timeout` need raising, and what is the risk of 1h?
3. What did you give up by disabling buffering on this endpoint?

## Expected outcome

Streaming works through the edge, and buffering remains on everywhere else.

## Staged hints

<details><summary>Hint 1 — question 3</summary>

With buffering on, NGINX reads the upstream response as fast as the upstream can
produce it, frees the backend worker, and then feeds the client at whatever pace
the client manages. With it off, a slow client holds a backend connection open
for the whole transfer. That is the Slowloris exposure, and it is why you scope
the change to one location rather than turning it off globally.
</details>

<details><summary>Hint 2 — the header nobody remembers</summary>

Some setups also need `X-Accel-Buffering: no` from the upstream, which NGINX
honours per response. That is useful when you cannot change the NGINX config —
the application asks not to be buffered.
</details>
