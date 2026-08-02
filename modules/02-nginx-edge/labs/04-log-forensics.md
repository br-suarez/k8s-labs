# Lab 02.04 — Log forensics

**CORE · 40 min**

## Context

You are on call. Alerting fired at 14:25 for "p99 latency above 5 seconds on the
edge". By the time you look, it has recovered. You have the access log and
nothing else. The backend team says their dashboards were flat the whole time and
they are pushing back.

Who is right?

## Setup

```bash
cd modules/02-nginx-edge/labs
./gen-incident-log.sh access.log
```

**Do not read `gen-incident-log.sh` first.** Generate, analyse, then check your
answer against it. Reading it first turns a diagnostic exercise into a reading
exercise.

Log format:

```
$remote_addr - - [$time_local] "$request" $status $body_bytes_sent
  rt=$request_time uct=$upstream_connect_time urt=$upstream_response_time
  ucs=$upstream_cache_status
```

## The problem

Answer these from the log alone, and write the command that produced each answer:

1. What was the p50, p95 and p99 of `$request_time` per minute across the whole
   window? When exactly does it degrade and when does it recover?
2. Do the same for `$upstream_response_time`. **Compare the two shapes.**
3. Is the backend team right?
4. Which clients are affected? Is it uniform or concentrated?
5. What are those clients requesting that everyone else is not?
6. There are some 499 responses. What is a 499, who generates it, and what does
   its presence tell you?
7. The cache status column changes behaviour during the incident. Why, and is
   that a cause or a symptom?
8. Write the one-paragraph incident summary you would post. State the root
   cause, whether it was your outage, and what you would change.

## Expected outcome

All eight answered, each with the command. Answer 3 must be unambiguous —
"maybe" is not an on-call answer.

## Useful starting points

```bash
# Extract a field
awk '{for(i=1;i<=NF;i++) if($i ~ /^rt=/) print substr($i,4)}' access.log

# Percentiles per minute
awk '{
  split($4, t, ":"); minute = t[2] ":" t[3]
  for (i=1; i<=NF; i++) if ($i ~ /^rt=/) print minute, substr($i,4)
}' access.log | sort -k1,1 -k2,2g | awk '
  { v[$1][++n[$1]] = $2 }
  END { for (m in v) { c=n[m]; printf "%s p50=%.3f p95=%.3f p99=%.3f n=%d\n",
        m, v[m][int(c*0.5)+1], v[m][int(c*0.95)+1], v[m][int(c*0.99)+1], c } }
' | sort
```

## Staged hints

<details><summary>Hint 1 — the shape comparison</summary>

Plot both, even crudely with `sort | uniq -c`. If `$request_time` climbs while
`$upstream_response_time` stays flat, the backend produced its response just as
fast as always. The time went somewhere between NGINX and the client.
</details>

<details><summary>Hint 2 — 499</summary>

499 is NGINX-specific: the client closed the connection before NGINX finished
responding. It is not a server error. A cluster of 499s alongside very high
`$request_time` and very low `$upstream_response_time` is a strong signature —
and it points away from your backend, not at it.
</details>

<details><summary>Hint 3 — the requests themselves</summary>

Look at `$body_bytes_sent` for the slow requests versus the fast ones. Then look
at the request line. The difference is not subtle once you group by it.
</details>

## Why this lab exists

The most valuable on-call skill is deciding, quickly, whether a problem is yours.
`$request_time` versus `$upstream_response_time` answers that question for
anything behind a proxy, and getting it backwards sends an entire team optimising
a backend that was never slow.
