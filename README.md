# 🚀 k8s-bootstrap

[![CI](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/ci.yml)
[![Release](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/release.yml/badge.svg)](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/release.yml)

Bootstrap Kubernetes clusters on Raspberry Pi using [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

The workload cluster is bootstrapped by [Flux](https://fluxcd.io/) using the [k8s-infrastructure](https://github.com/mmontes11/k8s-infrastructure) repository.

### System compatibility

This Kubernetes installation has been verified on Ubuntu 24.04 running on both Raspberry Pi 4 and 5.

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

### Alternative installation flavours

- [k8s-management](https://github.com/mmontes11/k8s-management): Cluster API based installation.
- [k8s-bootstrap-talos](https://github.com/mmontes11/k8s-bootstrap-talos): Talos based installation.