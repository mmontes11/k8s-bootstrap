#!/bin/bash

set -euo pipefail

compute_nodes=(
  k8s-master
  k8s-worker0
)
worker_nodes=(
  k8s-worker0
  k8s-worker1
  k8s-worker2
)
# TODO: sync with config/kubeadm-init.yaml
POD_CIDR="10.244.0.0/24"

for i in "${!compute_nodes[@]}"; do
  kubectl label node "${compute_nodes[$i]}" node.mmontes.io/type=compute --overwrite 
done

# TODO: kubeadm init v1.22.9 does not seem to update the worker podCIDR. Verify this when upgrading to >1.23.x
for i in "${!worker_nodes[@]}"; do
  kubectl patch node "${worker_nodes[$i]}" -p "{\"spec\":{\"podCIDR\":\"$POD_CIDR\"}}"
done