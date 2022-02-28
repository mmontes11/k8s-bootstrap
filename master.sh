#!/bin/bash

set -euox pipefail

source ./scripts/lib.sh

install_scripts=(
  "scripts/network.sh"
  "scripts/containerd.sh"
  "scripts/kubeadm.sh"
)

for i in "${!install_scripts[@]}"; do
  source "${install_scripts[$i]}"
done

kubeadm init --config=config/kubeadm/init-config.yaml

USER=$(get_user)
USER_HOME=$(get_user_home)

mkdir -p $USER_HOME/.kube
cp /etc/kubernetes/admin.conf $USER_HOME/.kube/config
chown $(id -u $USER):$(id -g $USER) $USER_HOME/.kube/config