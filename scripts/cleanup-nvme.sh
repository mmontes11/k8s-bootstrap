#!/bin/bash

# see:
# https://rook.io/docs/rook/latest-release/Getting-Started/ceph-teardown/
# https://rook.io/docs/rook/latest-release/Getting-Started/Prerequisites/prerequisites/#ceph-prerequisites
#
# Wipe the rook-ceph partition of the RPi5 NVMe layout
# (see docs/rpi5-nvme-storage-node.md): /dev/nvme0n1p3 by default.
# Pass another partition explicitly if the layout differs (e.g. the legacy
# whole-disk /dev/nvme0n1 on a node that has not been migrated yet).
# No checks are performed: the caller is responsible for providing the
# correct target device.

set -euo pipefail

PART="${1:-/dev/nvme0n1p3}"

# Wipe a large portion of the beginning of the target to remove LVM metadata that may be present
dd if=/dev/zero of="$PART" bs=1M count=100 oflag=direct,dsync status=none

# SSDs may be better cleaned with blkdiscard instead of dd
blkdiscard "$PART"

# Inform the OS of partition table changes
partprobe "${PART%p*}"

# Remove rook directory
rm -rf /var/lib/rook
