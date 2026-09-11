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

### Renew a worker node's kubelet client certificate

Worker nodes join the Talos control-plane as Ubuntu machines. On join, the
kubelet performs TLS bootstrap and mints its **own** node client certificate
(subject `O=system:nodes, CN=system:node:<name>`), signed by the cluster CA.
Together with its private key it is stored combined in
`/var/lib/kubelet/pki/kubelet-client-current.pem` and is valid for one year.

This certificate is **not** a copy of the control-plane certificate and does not
track control-plane rotations. It is the node's own identity and expires on its
own schedule. On some kubelet versions the kubelet does not rotate it by itself
(the serving certificate, stored the same way, is rotated; the client certificate
is not). When it expires the kubelet can no longer authenticate to the API
server: the node goes `NotReady` and `KubeClientCertificateExpiration` fires
against the control-plane.

Renew it through the Certificates API. The script re-uses the node's existing
private key and subject, so the renewal is auto-approved as the same node
identity (no manual approval needed), installs the new certificate in the same
combined layout and restarts the kubelet. It is idempotent and the private key
never leaves the node:

```bash
TARGET_NODE=<host> ./scripts/kubelet-client-rotate.sh
```

Useful variations:

```bash
# Validate the mechanism on one node first: submits (and then deletes) the
# certificate request, confirms it is signed, but does not touch the kubelet.
TARGET_NODE=<host> DRY_RUN=1 ./scripts/kubelet-client-rotate.sh

# Override the k8s node name (defaults to the node's hostname).
TARGET_NODE=<host> NODE_NAME=<k8s-node-name> ./scripts/kubelet-client-rotate.sh
```

The script prints the old and new certificate subject and `notAfter` so you can
confirm the expiry moved into the future. Repeat on each worker node. The
kubelet is restarted, so expect a few seconds of node `NotReady` (running pods
are briefly rescheduled off the node and back).

### Re-copy control-plane certificates to a worker node

If a worker node's copies of the control-plane CA and kubelet kubeconfig have
drifted (for example after a control-plane certificate rotation), re-copy the
current control-plane certificates to the node and restart its kubelet:

```bash
TALOS_CONTROLPLANE=<host> \
TARGET_NODE=<host> \
./scripts/talos-rotate.sh
```

This refreshes `/etc/kubernetes/kubelet.conf`, the bootstrap kubelet
kubeconfig and `ca.crt` only. It does **not** renew the node's own
TLS-bootstrap client certificate described above -- use
`./scripts/kubelet-client-rotate.sh` for that.

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
