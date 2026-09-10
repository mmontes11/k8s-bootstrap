# 🚀 k8s-bootstrap

[![CI](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/ci.yml)
[![Release](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/release.yml/badge.svg)](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/release.yml)

Bootstrap Kubernetes clusters using [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

The workload cluster is bootstrapped by [Flux](https://fluxcd.io/) using the [k8s-infrastructure](https://github.com/mmontes11/k8s-infrastructure) repository.

### Alternative installation flavours

- [k8s-management](https://github.com/mmontes11/k8s-management): Cluster API based installation.
- [k8s-bootstrap-talos](https://github.com/mmontes11/k8s-bootstrap-talos): Talos based installation.

### System compatibility

This Kubernetes installation has been verified on Ubuntu 24.04.

### Node preparation

Execute the provided script on all nodes (both control plane and worker nodes) prior to starting the installation process:

```bash
sudo bash node-prepare.sh
```

Once completed, reboot the node and proceed with the [installation](#installation).

### Installation

Setup the control-plane by running:
```bash
sudo bash control-plane.sh
```

Copy the kubeadm configuration files `config/kubeadm-join.<node-type>.yaml` to each node and run this command to join the cluster:
```bash
sudo bash node.sh 'config/kubeadm-join.<node-type>.yaml' 
``` 

Run this on the control-plane for bootstrapping the [infrastructure](https://github.com/mmontes11/k8s-infrastructure):
```bash
export GITHUB_USER=mmontes11
export GITHUB_REPO=k8s-infrastructure 
export GITHUB_BRANCH=main
export GITHUB_PATH=clusters/homelab
export GITHUB_TOKEN=<your-personal-access-token>
./bootstrap.sh
```

### Add worker node to a existing Talos cluster

Generate the Kubernetes configuration files from the Talos control-plane and copy them to the target node:

```bash
TALOS_CONTROLPLANE=<host> \
TARGET_NODE=<host> \
KUBELET_EXTRA_ARGS="--node-labels=node.mmontes.io/type=<type> --register-with-taints=node.mmontes.io/type=<type>:NoSchedule" \
./scripts/talos-config.sh
```

Run this command __in the target node__ to join the cluster:

```bash
sudo \
SKIP_KUBEADM_JOIN="true" \
bash node.sh
```

### Rotate worker node certificates

Worker nodes join the Talos control-plane as Ubuntu machines. Their kubelet
client certificate is a copy of the control-plane's, taken at join time, and it
does not track later control-plane certificate rotations. When that copy
expires the kubelet can no longer authenticate: the node goes `NotReady` and
`KubeClientCertificateExpiration` alerts fire against the control-plane.

Talos keeps the control-plane certificates current on its own (they are rotated
on upgrade and config changes), so rotating a worker is just re-copying the
current control-plane certificates to the node and restarting its kubelet.

Regenerate the worker's certificates from the control-plane and restart the
kubelet:

```bash
TALOS_CONTROLPLANE=<host> \
TARGET_NODE=<host> \
./scripts/talos-rotate.sh
```

The script prints the new client certificate's subject and `notAfter` before it
installs anything — confirm the expiry is in the future. Repeat on each worker
node. The kubelet is restarted, so expect a few seconds of node `NotReady`.

### Upgrade worker node

Run the following commands to upgrade containerd and kubelet in a worker node:

```bash
sudo \
UPGRADE="1" \
CONTAINERD_VERSION="2.2.1-1~ubuntu.24.04~noble" \
bash scripts/containerd.sh
```
```bash
sudo \
UPGRADE="1" \
KUBERNETES_VERSION="v1.35" \
KUBERNETES_PKG="1.35.0-1.1" \
bash scripts/kubernetes.sh
``` 

### Kubeconfig

`admin` and `super-admin` kubeconfigs are available in the following control-plane paths:
- `/etc/kubernetes/admin.conf`
- `/etc/kubernetes/super-admin.conf`

This [article](https://raesene.github.io/blog/2024/01/06/when-is-admin-not-admin/) depicts the differences between them.

### Raspberry Pi 5 NVMe storage nodes

Storage nodes booting from onboard NVMe are provisioned with a dedicated raw partition
for rook-ceph. See [docs/rpi5-nvme-storage-node.md](docs/rpi5-nvme-storage-node.md) for
the migration runbook — including the golden-image flow used to set up the remaining
nodes.
