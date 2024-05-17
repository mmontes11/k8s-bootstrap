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

setup_kubeconfig root /root
setup_kubeconfig $(get_user) $(get_user_home)

curl -sfL https://raw.githubusercontent.com/mmontes11/k8s-tooling/main/kubernetes.sh | bash -s -