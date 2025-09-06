#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

SKIP_KUBEADM_JOIN=${SKIP_KUBEADM_JOIN:-false}

if [ "$SKIP_KUBEADM_JOIN" = "false" ]; then
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <join-config-file>"
    exit 1
  fi
  JOIN_CONFIG_FILE="$1"
  if [ ! -f "$JOIN_CONFIG_FILE" ]; then
    echo "Join configuration file '$JOIN_CONFIG_FILE' not found"
    exit 1
  fi
fi

INSTALL_SCRIPTS=(
  "scripts/apt.sh"
  "scripts/swap.sh"
  "scripts/network.sh"
  "scripts/storage.sh"
  "scripts/containerd.sh"
  "scripts/kubernetes.sh"
)
for INSTALL in "${INSTALL_SCRIPTS[@]}"; do
  source "$INSTALL"
done

if [ "$SKIP_KUBEADM_JOIN" = "false" ]; then
  echo "🔌 Joining Kubernetes cluster..."
  kubeadm join --config "$JOIN_CONFIG_FILE"
else
  echo "⏭️ Skipping kubeadm join step (SKIP_KUBEADM_JOIN=true)"
fi

echo "🚜 Node installation completed successfully!"