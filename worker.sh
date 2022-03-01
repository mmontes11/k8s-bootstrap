#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

required_env_vars=(
  "API_SERVER_ENDPOINT"
  "TOKEN"
  "CA_CERT_HASH"
)

for i in "${!required_env_vars[@]}"; do
  ensure_env_var "${required_env_vars[$i]}"
done

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

kubeadm join $API_SERVER_ENDPOINT \
  --token $TOKEN \
  --discovery-token-ca-cert-hash $CA_CERT_HASH \
  --cri-socket=/run/containerd/containerd.sock