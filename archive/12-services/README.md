# Lab 12: Services

**Module:** 12 - Services
**Date:** 2026-07-12

## Objective
Expose the `practice-web` Deployment (Lab 09) through a stable network identity using a `ClusterIP` Service, and confirm in-cluster DNS resolution and load-balancing across its Pods — replacing the manual `port-forward` approach used in earlier labs.

## What I did

1. Created a ClusterIP Service (`service-clusterip.yaml`):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: practice-web-service
  namespace: practice-app
spec:
  type: ClusterIP
  selector:
    app: practice-web
  ports:
    - port: 80
      targetPort: 80
```

2. Applied it and verified endpoint discovery:
```bash
kubectl apply -f service-clusterip.yaml
kubectl get services -n practice-app
kubectl describe service practice-web-service -n practice-app
```
Result confirmed the Service automatically discovered all matching Pods via the `app=practice-web` selector:
Selector:    app=practice-web
Type:        ClusterIP
IP:          10.96.205.16
Port:        <unset>  80/TCP
TargetPort:  80/TCP
Endpoints:   10.244.0.18:80,10.244.0.16:80,10.244.0.15:80 + 1 more...

3. Tested in-cluster DNS resolution and load balancing using a temporary debug Pod:
```bash
kubectl run test-curl --image=curlimages/curl -n practice-app --rm -it -- curl practice-web-service
```
Successfully returned the nginx default welcome page, confirming the Service's DNS name (`practice-web-service`, resolved by CoreDNS) correctly routed to one of the backing Pods.

## Issue encountered

The `test-curl` debug Pod initially failed:
Error from server (Forbidden): pods "test-curl" is forbidden: exceeded quota: practice-app-quota,
requested: limits.cpu=100m,pods=1,requests.cpu=50m, used: limits.cpu=600m,pods=6,requests.cpu=300m,
limited: limits.cpu=600m,pods=6,requests.cpu=300m

The `practice-app-quota` ResourceQuota from Lab 10 (`pods: 6`) was already fully consumed — 4 Pods from `practice-web` (Lab 09) plus 2 from `practice-web-configured` (Lab 11) left zero headroom for a new debug Pod.

## Solution / Troubleshooting

Rather than raising the quota, removed the `practice-web-configured` Deployment from Lab 11 (already fully documented, no longer needed running) to free up quota headroom:
```bash
kubectl delete deployment practice-web-configured -n practice-app
kubectl get pods -n practice-app
```
This freed 2 of the 6 quota-allotted pod slots, allowing `test-curl` to be scheduled successfully.

## Security note observed

`kubectl run ... --rm -it` printed a warning before attaching:
All commands and output from this session will be recorded in container logs,
including credentials and sensitive information passed through the command prompt.
Worth remembering alongside the Lab 11 finding about Secrets leaking into `last-applied-configuration` — interactive debug sessions are another place sensitive data can end up persisted in logs.

## What I learned

- A `Service` uses the exact same label-selector mechanism as ReplicaSets and Deployments — it doesn't "know" about specific Pods, it just continuously matches Pods by label and updates its `Endpoints` list as Pods come and go.
- `ClusterIP` (the default type) is only reachable from inside the cluster — this is the right choice for internal service-to-service communication, as opposed to `NodePort` or `LoadBalancer` for external access.
- CoreDNS automatically creates a DNS entry for every Service using its name (`practice-web-service` in this case) — Pods within the cluster never need to know or hardcode Service IPs.
- A Service transparently load-balances across all Pods listed in its `Endpoints`, so `curl practice-web-service` can land on any of the 4 backing Pods without the caller needing to choose.
- Quota limits from Lab 10 apply to *any* new Pod in the namespace, including short-lived debug Pods created with `kubectl run --rm` — a good reminder to keep quota headroom in mind when doing live troubleshooting in a constrained namespace.
