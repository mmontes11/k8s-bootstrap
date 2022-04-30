#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

ARCH=$(get_architecture)
if [ -z $ARCH ]; then
  echo "Architecture not supported"
  exit 1
fi

function setup_kubeconfig() {
  USER=$1
  USER_HOME=$2

  mkdir -p $USER_HOME/.kube
  cp /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  chown $(id -u $USER):$(id -g $USER) $USER_HOME/.kube/config
  chown $(id -u $USER):$(id -g $USER) $USER_HOME/.kube

  cp config/.kubectl $USER_HOME/.kubectl
  echo "source ~/.kubectl" >> $USER_HOME/.bashrc
  echo "source <(kubectl completion bash)" >> $USER_HOME/.bashrc
}

# kubeconfig
setup_kubeconfig root /root
setup_kubeconfig $(get_user) $(get_user_home)

# # helm
HELM_VERSION=v3.8.0
HELM_URL=https://get.helm.sh/helm-$HELM_VERSION-linux-$ARCH.tar.gz
install_tar helm $HELM_URL linux-$ARCH

# cilium
CILIUM_VERSION=v0.11.1
CILIUM_URL=https://github.com/cilium/cilium-cli/releases/download/$CILIUM_VERSION/cilium-linux-$ARCH.tar.gz
install_tar cilium $CILIUM_URL ""

# flux
FLUX_VERSION=0.27.4
FLUX_URL="https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${ARCH}.tar.gz"
install_tar flux $FLUX_URL ""