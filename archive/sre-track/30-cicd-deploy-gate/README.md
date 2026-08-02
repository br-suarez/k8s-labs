# Refresher 30: CI/CD — A Deploy Gate That Actually Blocks

**Module:** 30 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

A pipeline with a health gate between staging and production, run three times
against the live cluster: a good release, a release that is **broken but Ready**,
and one that cannot start.

```bash
./run-lab.sh
```

Evidence: [`01-gate-runs.txt`](./evidence/01-gate-runs.txt).

**On the workflow file:** [`workflows/deploy.yml`](./workflows/deploy.yml) is a
real GitHub Actions pipeline, but it is **not** executed here — it lives in the
module folder rather than `.github/workflows/` so that adding this lab to the
portfolio repo does not start running CI on every push. What *is* executed for
real is [`scripts/health-gate.sh`](./scripts/health-gate.sh), the gate itself.
Claiming a pipeline works because its YAML parses would be the kind of
unverified assertion these labs exist to avoid.

---

## The gate

Three checks, in increasing order of what they can detect:

| # | Check | Catches |
|---|-------|---------|
| 1 | `kubectl rollout status` | pods that never start |
| 2 | smoke test → `/healthz` | a service that does not answer |
| 3 | **SLO verification via Prometheus** | a service that answers *incorrectly* |

Check 3 is the one most pipelines skip, and the only one that catches the case
below.

---

## The three runs

### A — good release (`v3-fixed`) → **promoted**

```
[GATE] rollout completed
[GATE]      attempt 1/6 returned '000', retrying in 5s
[GATE] smoke test returned 200
[GATE] SLO verification passed
[GATE] PROMOTE APPROVED
PIPELINE RESULT: promoted v3-fixed to production
```

### B — broken but Ready (`v2-bad`, 20% 5xx) → **blocked**

```
[GATE] rollout completed
[GATE] smoke test returned 200
[GATE] BLOCKED: error ratio 0.1922258500605391 exceeds the 0.005 error budget
PIPELINE RESULT: v2-bad was NOT promoted
production is running: slo-demo:v3-fixed
```

**This is the case the gate exists for.** The rollout completed. The smoke test
returned 200. Kubernetes was entirely satisfied:

```
NAME                        READY   RESTARTS   IMAGE
checkout-68459497d7-68sl2   true    0          slo-demo:v2-bad
checkout-68459497d7-gwrvh   true    0          slo-demo:v2-bad
```

`READY=true`, `RESTARTS=0`, while one request in five returned 500. Readiness
probes answer *"is the process up"*, not *"is it working"*. Only a query against
real traffic could tell the difference, and it measured **19.2%** against a
**0.5%** budget.

### C — unstartable (`v9-nonexistent`) → **blocked at check 1**

```
[GATE] BLOCKED: rollout did not complete — pods never became Ready
PIPELINE RESULT: v9-nonexistent was NOT promoted
```

### Final state

```
$ kubectl get deploy checkout -n cicd-production -o jsonpath='{...image}'
slo-demo:v3-fixed
```

Production ran the one release that passed. Neither of the other two ever
reached it.

---

## What broke — the gate blocked a healthy release

The first version of the gate ran the smoke test **once**, and failed case A:

```
[GATE] BLOCKED: smoke test returned '000' instead of 200
PIPELINE RESULT: v3-fixed was NOT promoted
```

`http_code=000` is curl failing to connect at all — a race in the seconds
between `kubectl rollout status` returning and the Service endpoints catching up
with the new pods. The release was fine.

**A gate that produces false negatives is worse than no gate.** The team learns
that red means "run it again", and then ignores it on the day it is right. That
is how deploy gates get disabled — not by being defeated, but by being annoying.

**The fix** is to make the check answer the question actually being asked. "Is
this persistently broken?" not "was this instant unlucky?":

```bash
for attempt in $(seq 1 6); do
  SMOKE=$(... curl ... -w '%{http_code}')
  [[ "$SMOKE" == "200" ]] && break
  sleep 5
done
```

The re-run still shows `attempt 1/6 returned '000'` — the flakiness is real and
reproducible, it just no longer decides anything on its own.

---

## Design decisions worth defending

**No data is a block, not a pass.**

```bash
[[ "$ERR" == "nodata" ]] && fail "no metrics for this release — cannot verify, so cannot promote"
awk -v r="$REQ" 'BEGIN{exit !(r < 1)}' && fail "traffic too low to verify anything"
```

A release nobody sent requests to has not been verified; it has only been proven
to start. Treating "nothing to measure" as "nothing wrong" is how a gate becomes
decorative — and it is the same failure as module 29's saturation alert on a
metric that does not exist.

**The soak must outlast the rate window.** The gate waits 90s before querying a
`[1m]` rate. Query too early and the window still contains traffic served by the
*previous* version — the gate grades the release it just replaced and passes
anything.

**The gate is a script, not inline YAML.** It can be run by hand during an
incident, tested outside CI, and reused by the post-promotion verification step.
A gate that only exists inside a workflow file cannot be exercised or debugged.

**Automated verification first, human approval second.** The GitHub Environment
with required reviewers sits on `deploy-production`, which `needs: gate`. The
approval button is not offered until the automated SLO check has already passed.
A human asked to approve without evidence approves, every time.

---

## What I re-learned

- **"Ready" is not "working", and this is the single most repeated lesson across
  these labs.** Same finding as [module 21](../21-argocd-canary/README.md)'s
  canary and [module 22](../22-toil-automation/README.md)'s triage: two pods,
  `READY=true`, `RESTARTS=0`, failing 19.2% of requests. Every Kubernetes-native
  signal was green. The gate needed an SLI to see it.

- **The failure mode of a gate is a false negative, not a false positive.** A
  gate that wrongly blocks gets bypassed, and then it is not a gate. Retries and
  soak windows are not leniency — they are what makes the signal trustworthy
  enough to be obeyed.

- **`concurrency` in the workflow is a correctness control, not a cost control.**
  Two merges racing through staging means the gate queries Prometheus while an
  unrelated release is running and grades the wrong artifact.

- **Promote the artifact that passed, never rebuild it.** The workflow passes
  `needs.build.outputs.tag` forward instead of rebuilding on the production job.
  A rebuild produces a different image from the one the gate verified, which
  quietly makes the verification meaningless.
