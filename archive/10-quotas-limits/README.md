markdown# Lab 10: Quotas and Limits

**Module:** 10 - Quotas and Limits
**Date:** 2026-07-11

## Objective
Apply a `ResourceQuota` and a `LimitRange` to the `practice-app` namespace (created in Lab 09, which previously had no restrictions at all), and confirm both the default-injection behavior of `LimitRange` and the hard-enforcement behavior of `ResourceQuota` under a real over-scaling attempt.

## What I did

1. Created a ResourceQuota for the namespace (`resourcequota.yaml`):
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: practice-app-quota
  namespace: practice-app
spec:
  hard:
    requests.cpu: "300m"
    requests.memory: "512Mi"
    limits.cpu: "600m"
    limits.memory: "1Gi"
    pods: "6"
```

2. Created a LimitRange to set per-container defaults (`limitrange.yaml`):
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: practice-app-limits
  namespace: practice-app
spec:
  limits:
    - type: Container
      default:
        cpu: "100m"
        memory: "128Mi"
      defaultRequest:
        cpu: "50m"
        memory: "64Mi"
```

3. Applied both and verified:
```bash
kubectl apply -f resourcequota.yaml
kubectl apply -f limitrange.yaml
kubectl describe resourcequota practice-app-quota -n practice-app
kubectl describe limitrange practice-app-limits -n practice-app
```

`ResourceQuota` immediately reflected the existing 4 running Pods from Lab 09:
Resource         Used   Hard

limits.cpu       400m   600m
limits.memory    512Mi  1Gi
pods             4      6
requests.cpu     200m   300m
requests.memory  256Mi  512Mi

`LimitRange` confirmed the configured defaults (matching what Lab 09's Deployment already specified explicitly):
Type        Resource  Min  Max  Default Request  Default Limit

Container   cpu       -    -    50m              100m
Container   memory    -    -    64Mi             128Mi

4. Tested enforcement by scaling beyond the quota's pod limit:
```bash
kubectl scale deployment practice-web -n practice-app --replicas=8
kubectl get pods -n practice-app
kubectl describe deployment practice-web -n practice-app
kubectl describe replicaset practice-web-79d885bfbc -n practice-app
```

## Issue encountered (expected, part of the test)

Scaling to 8 replicas partially failed. The Deployment showed:
Replicas: 8 desired | 6 updated | 6 total | 6 available | 2 unavailable
Conditions:
ReplicaFailure   True    FailedCreate

The ReplicaSet's events showed the exact rejection from the API server:
Warning  FailedCreate  replicaset-controller  Error creating: pods "practice-web-79d885bfbc-rhx6l" is forbidden:
exceeded quota: practice-app-quota, requested: limits.cpu=100m,pods=1,requests.cpu=50m,
used: limits.cpu=600m,pods=6,requests.cpu=300m, limited: limits.cpu=600m,pods=6,requests.cpu=300m

The ReplicaSet controller retried repeatedly (visible as multiple `FailedCreate` events, eventually collapsed into a `(combined from similar events)` summary by Kubernetes' event aggregation) but was correctly blocked from exceeding the quota's `pods: 6` hard limit.

## Solution / Troubleshooting

This wasn't a bug to fix — it's the ResourceQuota working as intended. Scaled back down to restore the namespace to its expected state:
```bash
kubectl scale deployment practice-web -n practice-app --replicas=4
kubectl get pods -n practice-app
```

## What I learned

- `ResourceQuota` and `LimitRange` solve different problems: `LimitRange` sets **defaults and per-container bounds** (so a Pod without explicit `resources` still gets sane values), while `ResourceQuota` sets a **hard ceiling for the whole namespace** across all Pods combined.
- `ResourceQuota` enforcement happens at admission time, at the API server level — a Deployment/ReplicaSet can still declare a higher desired replica count than the quota allows, but the excess Pods will simply fail to be created, with a clear `forbidden: exceeded quota` message, rather than the whole operation being rejected outright.
- This means a Deployment's `desired` count and `available` count can diverge indefinitely if the quota isn't raised or the desired count isn't lowered — it doesn't self-correct back down automatically.
- The ReplicaSet controller retries pod creation repeatedly on quota rejection; Kubernetes' event system automatically collapses repeated identical events into a single `(combined from similar events)` entry to avoid flooding the event log.
- In a real multi-tenant cluster, this is exactly the mechanism that prevents one team or app from starving others of cluster resources — connects directly to the resource-usage investigation from Lab 09, where an *unrestricted* namespace was part of what made cluster-wide usage harder to reason about.
