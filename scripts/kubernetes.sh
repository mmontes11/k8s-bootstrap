#!/bin/bash

set -euo pipefail

# see:
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl

KUBERNETES_VERSION=v1.34
KUBERNETES_PKG=1.34.1-1.1

curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list

cp config/crictl.yaml /etc/crictl.yaml
mkdir -p /etc/kubernetes/manifests

apt update
apt install -y --allow-change-held-packages kubelet=${KUBERNETES_PKG} kubeadm=${KUBERNETES_PKG} kubectl=${KUBERNETES_PKG}
apt-mark hold kubelet kubeadm kubectl

systemctl enable --now kubelet