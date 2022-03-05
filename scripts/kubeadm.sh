#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

ARCH=$(get_architecture)
if [ -z $ARCH ]; then
  echo "Architecture not supported: '$ARCH'"
  exit 1
fi

KUBERNETES_VERSION=v1.22.7
BIN_DIR=/usr/local/bin 

# cni
CNI_VERSION="v0.8.2"
mkdir -p /opt/cni/bin
curl -L \
  "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" | \
  tar -C /opt/cni/bin -xz

# crictl
CRICTL_VERSION="v1.22.0"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | \
  tar -C ${BIN_DIR} -xz

# kubeadm
cd $BIN_DIR
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}
cd -

RELEASE_VERSION="v0.4.0"
curl -sSL \
  "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | \
  sed "s:/usr/bin:${BIN_DIR}:g" | \
  tee /etc/systemd/system/kubelet.service

mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL \
  "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | \
  sed "s:/usr/bin:${BIN_DIR}:g" | \
  tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl enable --now kubelet