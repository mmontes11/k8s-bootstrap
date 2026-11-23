#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

# see:
# https://github.com/rook/rook/issues/1312

# kernel modules
cat <<EOF | tee /etc/modules-load.d/rook-ceph.conf
rbd
ceph
EOF

modules=(
  rbd
  ceph
)

for i in "${!modules[@]}"; do
  modprobe -- "${modules[$i]}"
done

sysctl --system

# disk utilities
# nvme-cli is not part of the base image; the nodes need it for NVMe
# diagnostics (SMART/error logs, RMA evidence — see scripts/nvme-smart.sh).
apt install -y nvme-cli