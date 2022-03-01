#!/bin/bash

set -euo pipefail

install_scripts=(
  "scripts/apt.sh"
  "scripts/network.sh"
  "scripts/containerd.sh"
  "scripts/kubeadm.sh"
  "scripts/kubelet.sh"
)

for i in "${!install_scripts[@]}"; do
  source "${install_scripts[$i]}"
done

kubeadm config images pull --config=config/kubeadm.yaml
kubeadm init --config=config/kubeadm.yaml

post_install_scripts=(
  "scripts/kubectl.sh"
  "scripts/worker-join-info.sh"
)

for i in "${!post_install_scripts[@]}"; do
  source "${post_install_scripts[$i]}"
done