#!/bin/bash

set -euox pipefail

install_scripts=(
  "scripts/network.sh"
  "scripts/containerd.sh"
  "scripts/kubeadm.sh"
)

for i in "${!install_scripts[@]}"; do
  source "${install_scripts[$i]}"
done

kubeadm init --config=config/kubeadm/init-config.yaml

source ./scripts/kubelet.sh