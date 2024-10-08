#!/bin/bash

set -euo pipefail

install_scripts=(
  "scripts/apt.sh"
  "scripts/swap.sh"
  "scripts/network.sh"
  "scripts/containerd.sh"
  "scripts/kubernetes.sh"
)

for i in "${!install_scripts[@]}"; do
  source "${install_scripts[$i]}"
done

kubeadm config images pull --config=config/kubeadm-init.yaml
kubeadm init --config=config/kubeadm-init.yaml

post_install_scripts=(
  "scripts/cli.sh"
  "scripts/join-config.sh"
)

for i in "${!post_install_scripts[@]}"; do
  source "${post_install_scripts[$i]}"
done

echo "control-plane installation completed successfully! 🚀"