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