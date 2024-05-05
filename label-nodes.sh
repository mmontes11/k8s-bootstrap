#!/bin/bash

set -euo pipefail

compute_nodes=(
  "worker2"
  "worker3"
  "worker4"
)

for node in "${compute_nodes[@]}"; do
  kubectl label node "$node" "node.mmontes.io/type=compute"
done
