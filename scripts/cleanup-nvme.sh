#!/bin/bash

# see:
# https://rook.io/docs/rook/latest-release/Getting-Started/ceph-teardown/
# https://rook.io/docs/rook/latest-release/Getting-Started/Prerequisites/prerequisites/#cpu-architecture

DISK="/dev/nvme0n1"

# Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
sgdisk --zap-all $DISK

# Wipe a large portion of the beginning of the disk to remove more LVM metadata that may be present
dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync

# SSDs may be better cleaned with blkdiscard instead of dd
blkdiscard $DISK

# Inform the OS of partition table changes
partprobe $DISK

# Remove rook directory
rm -rf /var/lib/rook