# Lab 09.02 — Caching, and where it lies

**CORE · 45 min**

## Context

Caching is the highest-leverage speedup in CI and the easiest place to make your
pipeline dishonest — a cache that serves stale content produces a green run that
proves nothing.

## The problem

### Part 1 — measure before optimising

Record, from three runs with no caching: total wall time, and the time of the
dependency-download and build steps individually.

```bash
gh run list --workflow=ci.yml --limit 3 --json databaseId,createdAt,updatedAt \
  -q '.[] | "\(.databaseId) \((.updatedAt[11:19]))"'
```

### Part 2 — cache Go modules

Add module caching keyed on the lockfile hash. Then measure again across three
runs.

1. What is the cache key, and why must the lockfile hash be in it?
2. What is a restore key, and what does a partial match give you?
3. Cache hit rate across your three runs?

### Part 3 — cache Docker layers

Add BuildKit cache. Measure the image build step before and after.

4. `type=gha` vs `type=registry` for the cache backend — trade-offs?
5. What is the cache size limit, and what happens when you exceed it?

### Part 4 — make the cache lie

This is the point of the lab. Construct a case where the cache produces a
**green run that should have failed**:

- Cache a build output rather than only dependencies.
- Change source code in a way that does not change the cache key.
- Watch CI reuse the stale artifact and pass.

6. What exactly went wrong? Which rule did you break?
7. What is safe to cache and what is not? Write the rule in one sentence.
8. `RUN apt-get update && apt-get install curl` in a cached layer: what is wrong
   with it three weeks later, and what is the fix that is *not* "disable the
   cache"?

## Expected outcome

Before/after timings for both caches, and a documented reproduction of a cache
serving a stale result, with the rule you derived.

## Staged hints

<details><summary>Hint 1 — question 7</summary>

Cache **inputs**, never **outputs**. Dependencies resolved from a lockfile are
inputs: the lockfile hash fully determines them, so a stale cache is impossible
without a key change. Build artifacts are outputs: their correctness depends on
source that may not be in the key. If you cannot express the complete set of
inputs in the cache key, do not cache it.
</details>

<details><summary>Hint 2 — question 4</summary>

`type=gha` uses GitHub's cache service: no setup, subject to the repository cache
quota, evicted by LRU. `type=registry` pushes cache layers to your registry:
unlimited by your own storage, shareable across repos and with local builds,
costs registry storage and pull time. For a single repo, `gha`. For an
organisation building the same base images repeatedly, `registry`.
</details>
