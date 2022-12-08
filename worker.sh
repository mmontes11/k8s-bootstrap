#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

JOIN_CONFIG_FILE=config/kubeadm-join.yaml

if [ ! -f $JOIN_CONFIG_FILE ]; then
  echo "Join configuration file '$JOIN_CONFIG_FILE' not found"
  exit 1
fi

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

kubeadm join --config $JOIN_CONFIG_FILE

echo "worker installation completed successfully! 🚜"