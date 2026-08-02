# Module 11 — Progressive Delivery

**4 blocks** (2 if you pass the diagnostic). Requires modules 10 and 07.

Depends on **07 as much as on 10**. A canary without metrics is a deployment with
pauses in it.

## Objectives

1. Release with automated analysis and automated rollback.
2. Gate promotion on the SLO defined in module 07, not on a timer.
3. Understand blast radius: how much traffic a bad release touches before the
   system notices.
4. Compare canary, blue/green and rolling honestly.

## Exit criteria

- [ ] I can configure a canary that rejects a bad release automatically, and
      state how many requests it affected before rejection.
- [ ] I can explain why a pause shorter than the metric's time-to-verdict
      multiplies blast radius, and calculate the correct minimum.
- [ ] I can defend canary against blue/green for Pulse specifically, and name a
      workload where blue/green is clearly better.
- [ ] Given a canary that promotes a broken release, I can identify whether the
      metric, the threshold or the timing was at fault.

## The insight this module is built around

The analysis interval must exceed the time it takes the metric to reflect
reality. A 30s pause on a metric computed over a 5m window promotes on data that
does not yet include the failure. This is the exact bug found in
`archive/sre-track/21-argocd-canary/` — a 3x blast radius increase — and this
module has you find it again, from the other direction: given the blast radius,
derive the timing error.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 09–10) | CORE | 15 min |
| 01 | Argo Rollouts (v1.9.1) with a weighted canary via Gateway API from module 05 | CORE | 45 min |
| 02 | AnalysisTemplate driven by the module 07 SLO | CORE | 50 min |
| 03 | **Reject a bad release**; measure requests affected before rollback | CORE | 50 min |
| 04 | Derive the minimum safe pause from the metric window; prove it | CORE | 45 min |
| 05 | Canary vs blue/green vs rolling — implement blue/green too, compare cost and risk | EXTEND | 45 min |
| 06 | The canary that promotes a broken release: three root causes, diagnose which | EXTEND | 40 min |

## Capstone layer

Pulse releases progressively. A deliberately broken image is rejected
automatically without human intervention, and the rollback is visible in the
metrics from module 07 and the traces from module 08.

## Verification

```bash
kubectl argo rollouts status pulse-api -n pulse
./platform/scripts/verify.sh canary
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
