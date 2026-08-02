# SETUP — Local environment

Target: **Ubuntu 24.04 on WSL2**. Everything runs locally except module 14, which
is the only module that spends money.

Verified against upstream releases on **2026-08-02**. Every version below is
pinned deliberately; `latest` is banned in this repo because a lab that passes
today and fails in three weeks teaches nothing.

---

## 0. The memory problem — read this first

This is the constraint most likely to kill the track around module 07.

A default WSL2 install takes **50% of host RAM**. Reported here: **7.7 GiB**. A
kind cluster with three workers plus kube-prometheus-stack plus an OTel Collector
plus Argo CD plus the Pulse platform will not fit. It will not fail cleanly
either — you will get evicted pods, OOMKilled Prometheus, and hours lost
debugging an environment problem that is not a Kubernetes lesson.

**Check what you have:**

```bash
free -h && nproc && cat /proc/meminfo | grep MemTotal
```

**Fix it before module 04.** On the Windows side, create or edit
`C:\Users\<you>\.wslconfig`:

```ini
[wsl2]
memory=12GB
processors=4
swap=8GB

# Reclaim freed memory back to Windows instead of holding it.
# Requires WSL 2.0+ — check with: wsl --version
autoMemoryReclaim=gradual

# Sparse VHD keeps the ext4 disk from growing forever as you build images.
sparseVhd=true
```

Then from PowerShell:

```powershell
wsl --shutdown
```

Only raise `memory` to about 75% of host RAM. If the host has 16 GB, 12 GB is
the ceiling; leaving Windows under 4 GB will make the whole machine swap.

**If you cannot raise it past 8 GB**, the track still works — use the `lite`
cluster profile throughout and run module 07's stack with the reduced-retention
values documented in that module. Say so in `TRACKER.md` so future-you knows why
the numbers differ.

---

## 1. Why kind, and not k3d or minikube

You will be asked this in an interview. The honest answer:

| | kind | k3d (k3s) | minikube |
|---|---|---|---|
| Control plane | Real kubeadm, upstream components | k3s: single binary, several components replaced | Real, but VM/driver-dependent |
| Datastore | etcd | SQLite by default (etcd optional) | etcd |
| Multi-node | Native, trivially | Yes | Awkward |
| Startup | ~45s | ~20s | ~60s |
| Memory floor | Higher | **Lower** | Highest |
| Teaches production failure modes | **Yes** | Partially | Yes |

**Choice: kind.** The reasoning that matters is the last row. k3d is genuinely
faster and lighter, and if this were a CI smoke-test environment it would be the
right call. But k3s replaces or bundles pieces — Traefik as the default ingress,
SQLite instead of etcd, a merged control-plane binary — and those are exactly the
components whose failure modes an SRE has to recognise. Debugging an etcd
problem, or a kube-proxy problem, is a lesson. Debugging around a k3s abstraction
that hid it is not.

Second reason: kind is a Kubernetes SIG project that tracks upstream releases
directly, so the API surface you learn is the API surface that exists.

**When I would choose otherwise:** k3d for CI pipelines where cluster startup
time is multiplied by every job, and for edge/IoT work where k3s is the actual
production target. minikube when a lab needs a real VM boundary or a specific
hypervisor driver.

---

## 2. Version matrix

| Tool | Pinned version | Released | Notes |
|---|---|---|---|
| kind | `v0.32.0` | 2026-06-02 | |
| Kubernetes (node image) | `v1.36.1` | | kind v0.32.0 default |
| kubectl | `v1.36.1` | | Match the cluster; skew of ±1 minor is supported |
| Helm | `v4.2.3` | 2026-07-09 | **Helm 4** — see the note below |
| Gateway API CRDs | `v1.6.1` | 2026-07-16 | Standard channel unless a lab says otherwise |
| Argo CD | `v3.4.6` | 2026-07-31 | |
| Argo Rollouts | `v1.9.1` | 2026-07-17 | |
| OTel Collector | `v0.157.0` | 2026-07-21 | |
| Terraform | `v1.15.8` | 2026-07-08 | |
| Trivy | `v0.72.0` | 2026-06-30 | |
| Cosign | `v3.1.2` | 2026-07-17 | |
| Kyverno | `v1.18.2` | 2026-07-10 | |

> **Helm 4 note.** Most tutorials, and every one of the reference lab repos, are
> written for Helm 3. Helm 4 changed CLI defaults and chart apiVersion handling.
> When you hit a command from an older guide that does not work, that is usually
> why — and it is a good habit to check `helm version` before blaming the chart.

### Deprecations these labs correct

The reference repos this curriculum draws from contain manifests that **no longer
apply to any supported cluster**. They are corrected here, not patched:

| What | Removed in | Replacement |
|---|---|---|
| `autoscaling/v2beta2` (HPA) | Kubernetes 1.26 | `autoscaling/v2` |
| `batch/v1beta1` (CronJob) | Kubernetes 1.25 | `batch/v1` |
| `sudo snap install kubectl` | — | Direct binary; snap needs systemd and misbehaves on WSL |

And one wording correction worth carrying into interviews: **Ingress is not
deprecated.** It is feature-frozen at `networking.k8s.io/v1` and Gateway API is
its successor. Saying "deprecated" in an architecture review will get you
corrected; "frozen, new work goes to Gateway API" is accurate.

---

## 3. Install

Run [`scripts/bootstrap.sh`](./scripts/bootstrap.sh), or work through it by hand
the first time — module 00 asks you to read it before running it.

```bash
./scripts/bootstrap.sh
```

It is idempotent: safe to re-run, and it reports what it changed. Verify with:

```bash
./scripts/verify-setup.sh
```

That script is the first thing you will extend in module 01, and it becomes the
verification harness used by every module afterwards.

### Docker inside WSL, not Docker Desktop

Install the engine directly in the WSL distro. Docker Desktop adds a second VM
and a proxy layer between you and the daemon, which costs memory you do not have
and hides `dockerd` behaviour you are supposed to be learning.

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
newgrp docker
```

Confirm the group took effect — this is the single most common first-day failure:

```bash
docker run --rm hello-world
```

If that needs `sudo`, your shell has not picked up the `docker` group. Open a new
WSL session rather than fighting it.

---

## 4. Cluster profiles

Do not use one cluster shape for the whole track. Profiles live in
[`platform/deploy/clusters/`](./platform/deploy/clusters/).

| Profile | Shape | Used by | Approx. RAM |
|---|---|---|---|
| `lite` | 1 control-plane + 1 worker | modules 01–06 | ~2.5 GiB |
| `standard` | 1 control-plane + 2 workers | modules 07–13 | ~4 GiB |
| `ha` | 3 control-plane + 2 workers | module 06 HA lab only | ~6 GiB, tear down after |

```bash
kind create cluster --config platform/deploy/clusters/lite.yaml
```

Delete the cluster between modules unless a lab says to keep it. Rebuilding is
cheap and it repeatedly proves your setup is reproducible — which is the actual
skill.

---

## 5. Cost control

Modules 00–13, 15 and 16 cost **nothing**. Only module 14 touches a cloud
account.

Rules that apply to every cloud lab in this repo, without exception:

1. Every lab states its estimated cost before the first command.
2. Every lab ends with a **teardown step**, and the module's `verify.sh` fails if
   billable resources still exist.
3. Nothing is created outside Terraform, so `terraform destroy` is always
   sufficient. This is why module 13 comes before module 14.
4. A billing budget with an alert is configured **before** the first resource, as
   the first lab of module 14 — not after.

Budget ceiling: **$30/month**, with headroom to $50 during the month you run
module 14. Realistic spend if you follow the teardown steps: **under $10 total**,
because GKE's free tier covers the management fee for one zonal cluster and the
rest is billed by the hour you actually leave it running.

---

## 6. Editor and shell

Not prescriptive, but two things pay for themselves immediately:

```bash
# kubectl autocompletion and a short alias
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

# shellcheck — module 01 makes the verification harness depend on it
sudo apt-get install -y shellcheck
```

Avoid `kubectl` plugins and TUI wrappers (k9s, lens) until module 06. They are
excellent tools and they will slow your learning right now, because they answer
questions you should be forming the commands for yourself.
