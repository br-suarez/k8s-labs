# Lab 01: Local Cluster Installation with Kind

**Module:** 01 - Installation (Kind)
**Date:** 2026-07-08

## Objective
Spin up a local Kubernetes cluster using Kind (Kubernetes IN Docker) as the practice environment for the rest of the labs.

## What I did

1. Verified prerequisites (Docker running):
```bash
docker --version
docker ps
```

2. Installed Kind v0.23.0:
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version
```

3. Created the cluster:
```bash
kind create cluster --name k8s-portfolio
```

4. Verified cluster status:
```bash
kubectl cluster-info --context kind-k8s-portfolio
kubectl get nodes
docker ps
```

## Issue encountered

On the first attempt to create the cluster, `kubeadm init` failed during the `wait-control-plane` phase:
[api-check] The API server is not healthy after 4m29.68757993s
Unfortunately, an error has occurred:
context deadline exceeded
This error is likely caused by:
- The kubelet is not running
- The kubelet is unhealthy due to a misconfiguration of the node in some way (required cgroups disabled)

## Solution / Troubleshooting

The actual root cause wasn't cgroups — it was the host system's (Linux) **inotify** limits, which were too low for the kubelet and control plane components to watch the files they need inside the Kind container.

Diagnosis:
```bash
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances
```

Fix (raise the limits and make them persistent):
```bash
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Cleaning up the failed attempt and retrying:
```bash
kind delete cluster --name k8s-portfolio
kind create cluster --name k8s-portfolio
```

Result: cluster created successfully, node in `Ready` state.
NAME                          STATUS   ROLES           AGE    VERSION
k8s-portfolio-control-plane   Ready    control-plane   2m4s   v1.30.0

## What I learned

- `kubeadm init` errors in Kind aren't always what the log suggests at first glance (it said "cgroups", the real issue was inotify) — it's worth checking host kernel limits before assuming a cluster configuration problem.
- `fs.inotify.max_user_watches` and `max_user_instances` are common host-level tuning knobs needed to run Kubernetes-in-Docker on Linux, especially on distros with low default values.
- Kind exposes the API server on a random local port (in this case `42619`), mapped to port 6443 inside the container — useful to know for connectivity debugging.
- `kubeadm init` errors in Kind aren't always what the log suggests at first glance (it said "cgroups", the real issue was inotify) — it's worth checking host kernel limits before assuming a cluster configuration problem.
- `fs.inotify.max_user_watches` and `max_user_instances` are common host-level tuning knobs needed to run Kubernetes-in-Docker on Linux, especially on distros with low default values.
- Kind exposes the API server on a random local port (in this case `42619`), mapped to port 6443 inside the container — useful to know for connectivity debugging.
