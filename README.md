# 🚀 k8s-bootstrap
Kubernetes cluster bootstrapping using [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

### System compatibility

This Kubernetes installation has been verified on Ubuntu 24.04 running on both Raspberry Pi 4 and 5.

### Node preparation

Execute the provided script on all nodes (both control plane and worker nodes) prior to starting the installation process:

```bash
sudo bash prepare-node.sh
```

Once completed, reboot the node and proceed with the [installation](#installation).

### Installation

Setup the controlplane by running:
```bash
sudo bash controlplane.sh
```

Copy the generated configuration `config/kubeadm-join.yaml` to each worker node and run this command to join the cluster:
```bash
sudo bash worker.sh 
``` 

Run this on the controlplane for bootstrapping the [infrastructure](https://github.com/mmontes11/k8s-infrastructure):
```bash
export GITHUB_USER=mmontes11
export GITHUB_REPO=k8s-infrastructure 
export GITHUB_BRANCH=main
export GITHUB_PATH=clusters/homelab
export GITHUB_TOKEN=<your-personal-access-token>
./bootstrap.sh
``` 

### Label nodes

In order to label nodes, run the following script in the controlplane:

```bash
./label-nodes.sh
```

### Kubeconfig

`admin` and `super-admin` kubeconfigs are available in the following controlplane paths:
- `/etc/kubernetes/admin.conf`
- `/etc/kubernetes/super-admin.conf`

This [article](https://raesene.github.io/blog/2024/01/06/when-is-admin-not-admin/) depicts the differences between them.