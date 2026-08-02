# Module 04 — Kubernetes Core

**4 blocks** (2 if you pass the diagnostic). Requires module 03.

Getting Pulse onto Kubernetes correctly — with the probes, resources and
lifecycle settings that make it survivable, not just running.

## Objectives

1. Deploy a multi-service application with correct health, resource and
   lifecycle configuration.
2. Reason about scheduling: why a pod is `Pending`, and what would fix it.
3. Configure autoscaling on `autoscaling/v2` and explain why the older API
   versions in most tutorials no longer exist.
4. Trace a request from outside the cluster to a container process.

## Exit criteria

- [ ] I can deploy Pulse to a fresh cluster from manifests I wrote, with no
      restarts and no manual steps.
- [ ] Given a `Pending` pod, I can name the cause from `describe` output alone
      and list the three distinct classes of cause.
- [ ] I can explain the difference between liveness, readiness and startup
      probes, and describe what a misconfigured liveness probe does under load.
- [ ] I can explain requests vs limits, and what QoS class my pods land in and
      why that matters during eviction.

## Labs

| # | Lab | Level | Time |
|---|---|---|---|
| 00 | Repaso (módulos 02–03) | CORE | 15 min |
| 01 | Deploy Pulse from scratch: Deployments, Services, ConfigMap, Secret | CORE | 50 min |
| 02 | Probes done properly — and then a liveness probe tuned to cause a cascading restart under load. Watch it happen | CORE | 50 min |
| 03 | Requests, limits and QoS: force an eviction, predict which pod dies first, verify | CORE | 45 min |
| 04 | HPA on `autoscaling/v2` with a custom metric; explain why `v2beta2` manifests fail on any supported cluster | CORE | 40 min |
| 05 | Trace a request end to end: Service → Endpoints → iptables/IPVS → container | EXTEND | 45 min |
| 06 | `terminationGracePeriodSeconds` vs your app's drain time — measure dropped requests | EXTEND | 30 min |

## Capstone layer

Pulse runs on kind, with a NodePort or port-forward for access. NGINX from module
02 still fronts it — **replacing it is module 05's job**, and doing them
separately is what makes the migration comparison real.

## Deprecation note

The reference labs this module draws from use `autoscaling/v2beta2`, removed in
Kubernetes 1.26, and `batch/v1beta1`, removed in 1.25. They will not apply to any
supported cluster. Lab 04 has you meet that failure deliberately, because reading
an `no matches for kind` error and knowing immediately what it means is a
recurring real-world skill.

## Verification

```bash
./platform/scripts/verify.sh k8s
```

---

## Problem → Solution → What I Learned

### Problem

### Solution

### What I Learned
