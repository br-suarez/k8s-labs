# Lab 08.06 — Keep every error at 1% sampling

**CORE · 45 min**

## Context

Tracing everything is unaffordable. Tracing randomly means the traces you need
are the ones you did not keep. This lab resolves that.

## The problem

### Part 1 — head sampling, and its ceiling

Configure the SDK with `TraceIDRatioBased(0.01)`.

```bash
# Generate load with a known error rate
kubectl set env deployment/pulse-api -n pulse INJECT_ERROR_RATE=0.02
```

Measure over ten minutes:

1. Requests total, errors total.
2. Traces stored, error traces stored.
3. What fraction of errors do you actually have traces for?

Then answer: **can you fix this with head sampling?** Try, and explain why not.

### Part 2 — tail sampling

Move the decision to the Collector:

```yaml
tail_sampling:
  decision_wait: 10s
  num_traces: 20000
  expected_new_traces_per_sec: 200
  policies:
    - name: errors
      type: status_code
      status_code: {status_codes: [ERROR]}
    - name: slow
      type: latency
      latency: {threshold_ms: 1000}
    - name: baseline
      type: probabilistic
      probabilistic: {sampling_percentage: 1}
```

Also set the SDK to `AlwaysSample` — the Collector now decides, so the SDK must
send everything to it.

Re-measure the three numbers from part 1.

### Part 3 — count the cost

4. What is the network volume between application and Collector now versus with
   head sampling? Measure it, do not estimate.
5. What is the Collector's memory doing? Why does `num_traces` drive it?
6. `decision_wait: 10s` — what happens to a trace that takes 30 seconds?
7. What does this do to the queue-crossing traces from lab 04, where the consumer
   runs 40 seconds after the producer?

Question 7 is important and easy to miss: a `decision_wait` shorter than your
queue latency means the policy evaluates an incomplete trace.

### Part 4 — the scaling problem

8. Run two Collector replicas. What breaks about tail sampling, specifically?
9. Sketch the fix. What component routes spans so that all spans of a trace reach
   the same instance?
10. What operational cost did you just take on, and would you accept it for
    Pulse?

### Part 5 — decide

Write a short recommendation in `NOTAS.md`: which sampling strategy for Pulse,
with the volume and cost numbers you measured supporting it. Include the case for
the option you rejected.

## Expected outcome

Measured error-trace capture rates under both strategies, cost measured rather
than assumed, and a defended recommendation.

## Staged hints

<details><summary>Hint 1 — why head sampling cannot do it</summary>

The decision happens at the first span, before anything has failed. You could
raise the rate to 100% and keep everything, but then you have not sampled at all.
There is no head-sampling configuration that keeps all errors and few successes,
because at decision time the two are indistinguishable.
</details>

<details><summary>Hint 2 — question 8</summary>

Spans of one trace are load-balanced across replicas, so no replica sees the
whole trace and each decides on a fragment. The fix is a `loadbalancing` exporter
in a front layer that hashes on trace ID, so all spans of a trace land on the
same backend Collector. That makes your Collector tier stateful and two-layered —
a real operational cost worth naming out loud.
</details>
