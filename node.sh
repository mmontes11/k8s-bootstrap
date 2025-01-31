#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

if [ $# -lt 1 ]; then
  echo "Usage: $0 <join-config-file>"
  exit 1
fi

JOIN_CONFIG_FILE="$1"
if [ ! -f $JOIN_CONFIG_FILE ]; then
  echo "Join configuration file '$JOIN_CONFIG_FILE' not found"
  exit 1
fi

INSTALL_SCRIPTS=(
  "scripts/apt.sh"
  "scripts/swap.sh"
  "scripts/ntp.sh"
  "scripts/network.sh"
  "scripts/storage.sh"
  "scripts/containerd.sh"
  "scripts/kubernetes.sh"
)
for INSTALL in "${INSTALL_SCRIPTS[@]}"; do
  source "$INSTALL"
done

kubeadm join --config $JOIN_CONFIG_FILE

echo "node installation completed successfully! 🚜"