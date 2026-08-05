# Lab 10.03 — App of apps

**CORE · 50 min**

## Context

One object that reconstructs an entire cluster. Powerful, and the blast radius
scales with it.

## The problem

### Part 1 — split Pulse into components

Turn the single `pulse` Application into several: `pulse-platform` (namespace,
RBAC, network policy), `pulse-data` (Postgres, Redis), `pulse-services`
(api, worker, web), `pulse-observability` (ServiceMonitors, PrometheusRules).

1. Why split at all? What do you gain over one Application?
2. What did you make harder?

### Part 2 — the root

Write a root Application whose source is a directory of Application manifests.

```
platform/deploy/argocd/
├── root.yaml
└── apps/
    ├── pulse-platform.yaml
    ├── pulse-data.yaml
    ├── pulse-services.yaml
    └── pulse-observability.yaml
```

Bootstrap the whole platform with one command:

```bash
kubectl apply -f platform/deploy/argocd/root.yaml
```

### Part 3 — prove it rebuilds

The real test:

```bash
kind delete cluster --name pulse
kind create cluster --config platform/deploy/clusters/standard.yaml
# install Argo CD, then:
kubectl apply -f platform/deploy/argocd/root.yaml
```

**Time it.** From empty cluster to Pulse serving traffic. Compare against the
timed rebuild you did in module 08c lab 00.

3. How much faster? What steps disappeared?
4. What still needs a human?

### Part 4 — the blast radius

Now the dangerous part. In a scratch cluster:

5. Set `prune: true` on the root, then remove one Application file from
   `apps/`. What happens to its workloads?
6. Make a typo in the root's `path` so it points at an empty directory. With
   `prune: true`, what happens? **Try it and watch.**
7. How do you protect against 6? There are at least three mechanisms.

Question 6 is how people delete production with a one-character mistake.

### Part 5 — protect it

Implement at least two protections and verify each works:

- `prune: false` on the root specifically
- A finalizer or `Prune=false` sync option on critical resources
- An AppProject restricting what the root may create and where
- Branch protection on the repo path — the real first line of defence

## Expected outcome

Full platform bootstrapped from one manifest, a timed rebuild compared against
module 08c, a reproduced accidental deletion in a scratch cluster, and two
protections working.

## Staged hints

<details><summary>Hint 1 — question 6</summary>

Argo renders the source, finds no Applications, and with pruning enabled
concludes every existing Application should be deleted. Those deletions cascade
to their workloads. It is fast, it is exactly what you configured, and it looks
like normal reconciliation in the audit log.
</details>

<details><summary>Hint 2 — the strongest protection</summary>

Not a flag: **branch protection plus review on the path Argo watches**. Argo
faithfully applies whatever is in Git, so the security boundary is write access
to Git, not Argo's configuration. Everything else is a seatbelt.
</details>

## Cleanup

Do this in a scratch cluster, not the one carrying your work.
