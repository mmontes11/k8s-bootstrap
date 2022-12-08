#!/bin/bash

set -euo pipefail

KUBERNETES_VERSION=1.25.4-00

curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

cp config/crictl.yaml /etc/crictl.yaml
mkdir -p /etc/kubernetes/manifests

apt update
apt install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION
apt-mark hold kubelet kubeadm kubectl