#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

# see:
# docs/rpi5-nvme-storage-node.md
# https://github.com/rook/rook/issues/1312

# dependencies for the RPi5 NVMe storage node runbook
# (nfs-common and wget are already installed by scripts/apt.sh;
# e2fsprogs and the coreutils/sysfs tools ship with the base image)
apt update
apt install \
  gdisk \
  parted \
  rpi-imager \
  zstd \
  -y

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