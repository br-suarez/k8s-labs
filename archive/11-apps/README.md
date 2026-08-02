# Lab 11: Apps — ConfigMaps and Secrets

**Module:** 11 - Apps (optional)
**Date:** 2026-07-12

## Objective
Deploy an application that consumes external configuration via `ConfigMap` and `Secret`, confirm both are correctly injected as environment variables, and verify how Secrets are actually stored (base64-encoded, not encrypted).

## What I did

1. Created a ConfigMap for non-sensitive configuration (`configmap.yaml`):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: practice-app-config
  namespace: practice-app
data:
  APP_ENV: "practice"
  APP_GREETING: "Hello from the portfolio cluster"
```

2. Created a Secret using `stringData` (plain text on write, auto-encoded by Kubernetes) (`secret.yaml`):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: practice-app-secret
  namespace: practice-app
type: Opaque
stringData:
  API_KEY: "demo-key-12345"
```

3. Created a Deployment consuming both via `envFrom` (`deployment-with-config.yaml`):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: practice-web-configured
  namespace: practice-app
  labels:
    app: practice-web-configured
spec:
  replicas: 2
  selector:
    matchLabels:
      app: practice-web-configured
  template:
    metadata:
      labels:
        app: practice-web-configured
    spec:
      containers:
        - name: nginx
          image: nginx:1.26
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: practice-app-config
            - secretRef:
                name: practice-app-secret
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
```

4. Applied everything and verified the environment variables landed inside the running container:
```bash
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment-with-config.yaml
kubectl get pods -n practice-app
kubectl exec -it -n practice-app practice-web-configured-869c97dc97-tg8n2 -- env | grep APP_
kubectl exec -it -n practice-app practice-web-configured-869c97dc97-tg8n2 -- env | grep API_KEY
```
Confirmed both ConfigMap values (`APP_ENV`, `APP_GREETING`) and the Secret value (`API_KEY=demo-key-12345`) were present as environment variables inside the container.

## Issue encountered

First `grep` for the Secret's environment variable used the wrong name (`grep APP_KEY` instead of `grep API_KEY`), returning nothing and momentarily looking like the Secret hadn't been injected.

## Solution / Troubleshooting

Simple naming mismatch — corrected the grep pattern to `API_KEY` (matching the actual key defined in the Secret manifest), which confirmed the value was present all along:
```bash
kubectl exec -it -n practice-app practice-web-configured-869c97dc97-tg8n2 -- env | grep API_KEY
# API_KEY=demo-key-12345
```

## Security finding: Secrets are not encrypted by default

Inspected the raw Secret object:
```bash
kubectl get secret practice-app-secret -n practice-app -o yaml
```
```yaml
apiVersion: v1
data:
  API_KEY: ZGVtby1rZXktMTIzNDU=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Secret","metadata":{...},"stringData":{"API_KEY":"demo-key-12345"},"type":"Opaque"}
type: Opaque
```

Two things stood out:

1. The `data.API_KEY` field is base64-encoded, not encrypted — trivially reversible:
```bash
echo "ZGVtby1rZXktMTIzNDU=" | base64 --decode
# demo-key-12345
```

2. **More notably**: the `kubectl.kubernetes.io/last-applied-configuration` annotation — automatically added by `kubectl apply` to support future diffing — contains the *original* `stringData` block with the secret value in **plain text**, sitting right in the Secret object's own metadata.

## What I learned

- `ConfigMap` and `Secret` are both consumed the same way from a Pod's perspective (`envFrom` / `valueFrom`) — the difference is purely in how Kubernetes stores and treats them, not in how the application accesses them.
- `stringData` is a write-only convenience field: you write plain text, Kubernetes base64-encodes it into `data` automatically — but `data` is still fully reversible with a single `base64 --decode` call, it is **not** encryption.
- Real Secret protection in Kubernetes requires additional layers not present in this local Kind setup — encryption at rest (`EncryptionConfiguration` on the API server), RBAC restricting who can `get`/`describe` Secrets, and often an external secrets manager (Vault, AWS Secrets Manager, etc.) rather than relying on native Secrets alone.
- A subtle, easy-to-miss leak vector: `kubectl apply`'s `last-applied-configuration` annotation can retain the plain-text version of values you thought were only stored encoded — worth being aware of before assuming a Secret manifest is "safe" once applied.

