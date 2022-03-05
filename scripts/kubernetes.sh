#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

function setup_kubeconfig() {
  USER=$1
  USER_HOME=$2

  mkdir -p $USER_HOME/.kube
  cp /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  chown $(id -u $USER):$(id -g $USER) $USER_HOME/.kube/config
  chown $(id -u $USER):$(id -g $USER) $USER_HOME/.kube

  cp config/.kubectl $USER_HOME/.kubectl
  source $USER_HOME/.kubectl
  cat $USER_HOME/.kubectl >> $USER_HOME/.bashrc
}

ARCH=$(get_architecture)
if [ -z $ARCH ]; then
  echo "Architecture not supported: '$ARCH'"
  exit 1
fi


# kubeconfig
setup_kubeconfig root /root
setup_kubeconfig $(get_user) $(get_user_home)

# helm
HELM_VERSION=v3.8.0
HELM_URL=https://get.helm.sh/helm-$HELM_VERSION-linux-$ARCH.tar.gz
install_tar helm $HELM_URL linux-$ARCH

# cilium
CILIUM_CLI_VERSION=v0.10.4
CILIUM_CLI_URL=https://github.com/cilium/cilium-cli/releases/download/$CILIUM_CLI_VERSION/cilium-linux-$ARCH.tar.gz
install_tar cilium $CILIUM_CLI_URL ""