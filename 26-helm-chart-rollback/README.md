# Refresher 26: Helm — Author a Chart, Upgrade, Roll Back

**Module:** 26 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

A chart written by hand (not `helm create` boilerplate), taken through install,
value upgrade, a broken release, and a rollback verified from outside the
cluster.

```bash
./run-lab.sh
```

Evidence: [`01-lifecycle.txt`](./evidence/01-lifecycle.txt).

---

## The chart

[`checkout-api/`](./checkout-api/) — Deployment, Service, ConfigMap, helpers.
Two decisions worth calling out:

**Labels are split into two sets.** `selectorLabels` go into
`spec.selector.matchLabels`, which is **immutable** on a Deployment. Putting
anything volatile there — like `version` — makes every subsequent upgrade fail
with `field is immutable`. Everything that changes lives in the wider `labels`
set instead.

**The pod template carries a hash of the ConfigMap:**

```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

Without it, changing a config value updates the ConfigMap and leaves the pods
running the old content. `helm upgrade` reports success, and nothing actually
changed. The hash turns a config change into a pod-template change, which is
what triggers a rollout.

---

## What broke — a failed upgrade that Helm calls a success

Revision 3 upgraded to an image tag that does not exist, with no `--wait` —
which is how most upgrade commands are actually written:

```
$ helm upgrade checkout ./checkout-api --set image.tag=v9-does-not-exist ...
Release "checkout" has been upgraded. Happy Helming!
STATUS: deployed
REVISION: 3
```

```
$ helm status checkout --output json | jq '.info | {status, description}'
{ "status": "deployed", "description": "Upgrade complete" }
```

Helm is not lying. It successfully pushed the manifests to the API server, and
that is all `helm upgrade` without `--wait` claims to do. The cluster disagrees:

```
NAME                                     READY   STATE               IMAGE
checkout-checkout-api-586c467898-dqrml   true    <none>              slo-demo:v1
checkout-checkout-api-586c467898-qkc2l   true    <none>              slo-demo:v1
checkout-checkout-api-586c467898-sfcz4   true    <none>              slo-demo:v1
checkout-checkout-api-76f65f9646-z2gl8   false   ErrImageNeverPull   slo-demo:v9-does-not-exist
```

**And the service kept working**, which is why this is easy to miss:

```
{"ok":true,"took_ms":107,"version":"v2"}
```

A Deployment will not tear down healthy replicas for a rollout that never
becomes Ready. `maxUnavailable` protects the old pods. So the release is broken,
Helm says deployed, monitoring is green, and the failure only surfaces the next
time something forces those old pods to reschedule.

---

## How it was diagnosed

`helm status` and `helm history` both report health from **Helm's** point of
view — did the manifests apply — not the cluster's.

```
$ helm history checkout -n helm-lab
REVISION  STATUS      CHART               APP VERSION  DESCRIPTION
1         superseded  checkout-api-0.1.0  v1           Install complete
2         superseded  checkout-api-0.1.0  v1           Upgrade complete
3         deployed    checkout-api-0.1.0  v1           Upgrade complete
```

Two traps in that output:

- Revision 3 is `deployed`, and it is broken.
- The **APP VERSION column reads `v1` on every row**, including revision 3 which
  shipped a completely different image. That column comes from `Chart.yaml`'s
  `appVersion`, not from the `.Values.appVersion` overridden with `--set`. The
  history gives no hint that the image changed at all.

**The key command** is the one that asks the cluster instead of Helm:

```bash
kubectl get pods -n helm-lab -o custom-columns=\
'NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATE:.status.containerStatuses[0].state.waiting.reason'
```

---

## The rollback

```bash
helm rollback checkout 2 --namespace helm-lab --wait
```

Verified on three independent things, because "the Deployment reverted" alone is
weak evidence:

```
# 1. pods
NAME                                     READY   IMAGE         VERSION
checkout-checkout-api-586c467898-dqrml   true    slo-demo:v1   v2
checkout-checkout-api-586c467898-qkc2l   true    slo-demo:v1   v2
checkout-checkout-api-586c467898-sfcz4   true    slo-demo:v1   v2

# 2. the ConfigMap — an unrelated object in the same release
{"feature-flags":"checkout_v2=on","greeting":"checkout-api v2"}

# 3. what the service actually serves
{"ok":true,"took_ms":59,"version":"v2"}
```

The `ErrImageNeverPull` pod is gone and the ConfigMap reverted to revision 2's
content — Helm rolls back the whole release, not just the workload.

### Rollback moves history forward

```
REVISION  STATUS      DESCRIPTION
3         superseded  Upgrade complete
4         deployed    Rollback to 2
```

It did **not** restore revision 2. It created revision **4** whose content
equals revision 2. Helm's history is append-only, so "roll back to the last good
one" means *finding* that revision, not decrementing a number — and after a
couple of incidents the newest revision can easily be a rollback of a rollback.

---

## `--atomic` — the flag that prevents all of this

Same broken upgrade, one flag different:

```
$ helm upgrade checkout ./checkout-api --set image.tag=v9-does-not-exist --atomic --timeout 90s
Error: UPGRADE FAILED: release checkout failed, and has been rolled back
       due to atomic being set: context deadline exceeded
```

Non-zero exit, so CI fails. And the cluster was restored automatically:

```
NAME                                     READY   IMAGE         VERSION
checkout-checkout-api-586c467898-dqrml   true    slo-demo:v1   v2
...
{"ok":true,"took_ms":79,"version":"v2"}
```

```
REVISION  STATUS      DESCRIPTION
5         failed      Upgrade "checkout" failed: context deadline exceeded
6         deployed    Rollback to 4
```

Helm recorded the failure *and* the automatic recovery. No human touched it.

---

## What I re-learned

- **`helm upgrade` without `--wait` reports on the API call, not the outcome.**
  "STATUS: deployed" means the manifests were accepted. Whether a single pod
  ever became Ready is a different question, and Helm was never asked it. Any
  pipeline that treats a zero exit code from a bare `helm upgrade` as "the
  deploy worked" is measuring the wrong thing.

- **A broken Deployment upgrade is a partial outage, and that makes it worse.**
  The old replicas stay up and keep serving, so the release looks fine from the
  outside while the cluster holds a workload that cannot start. It surfaces at
  the worst possible moment — the next node drain or scale event.

- **`--atomic` should be the default in CI, not the careful option.** It turns
  "broken release, green pipeline" into "failed pipeline, healthy cluster",
  which is the correct pairing. It costs a timeout budget and nothing else.

- **Rollback is append-only.** `helm rollback <rev>` creates a new revision. The
  number to roll back to has to be read out of `helm history`, and the useful
  column for that is `DESCRIPTION`, not `REVISION`.

- **`helm history`'s APP VERSION column comes from `Chart.yaml`, not from
  values.** Every row said `v1` while the release cycled through four different
  `APP_VERSION` values. If the image tag is a value rather than the chart's
  `appVersion`, the history will not show it — which is an argument for bumping
  `appVersion` and packaging a new chart version per release rather than
  `--set`-ing the tag at deploy time.

- **`checksum/config` is not optional.** Without it a ConfigMap-only change
  updates the object, skips the rollout, and produces a "successful" upgrade
  where the running pods never see the new config.
