#!/bin/bash

set -euo pipefail

install_scripts=(
  "scripts/network.sh"
  "scripts/containerd.sh"
  "scripts/kubeadm.sh"
)

for i in "${!install_scripts[@]}"; do
  source "${install_scripts[$i]}"
done

kubeadm init --config=config/kubeadm.yaml

post_install_scripts=(
  "scripts/kubelet.sh"
  "scripts/kubectl.sh"
)

for i in "${!post_install_scripts[@]}"; do
  source "${post_install_scripts[$i]}"
done