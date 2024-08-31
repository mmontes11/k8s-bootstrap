# 🚀 k8s-bootstrap

[![CI](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/ci.yml)
[![Release](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/release.yml/badge.svg)](https://github.com/mmontes11/k8s-bootstrap/actions/workflows/release.yml)

Bootstrap Kubernetes clusters on Raspberry Pi using [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

You may also take a look at the Talos installation: [k8s-bootstrap-talos](https://github.com/mmontes11/k8s-bootstrap-talos).

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

Copy the generated configuration files `config/kubeadm-join.<node-type>.yaml` to each node and run this command to join the cluster:
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

### Kubeconfig

`admin` and `super-admin` kubeconfigs are available in the following control-plane paths:
- `/etc/kubernetes/admin.conf`
- `/etc/kubernetes/super-admin.conf`

This [article](https://raesene.github.io/blog/2024/01/06/when-is-admin-not-admin/) depicts the differences between them.
