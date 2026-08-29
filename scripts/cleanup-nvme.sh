#!/bin/bash

# see:
# https://rook.io/docs/rook/latest-release/Getting-Started/ceph-teardown/
# https://rook.io/docs/rook/latest-release/Getting-Started/Prerequisites/prerequisites/#ceph-prerequisites
#
# Two supported disk layouts:
# - Legacy: the whole device is a rook device (OS runs from an SD card or other disk).
#   The entire disk is zapped, as before.
# - k8s-bootstrap RPi5 NVMe layout (see docs/rpi5-nvme-storage-node.md): the OS runs from
#   a partition of the device (e.g. nvme0n1p2) and rook owns a dedicated partition
#   (e.g. nvme0n1p3). In that case only the rook partition may be wiped; the disk and
#   the OS partitions are never touched.

set -euo pipefail

DISK="${1:-/dev/nvme0n1}"

[ -b "$DISK" ] || { echo "error: $DISK is not a block device" >&2; exit 1; }

# Does the OS run from a partition of $DISK?
ROOT_DEV=$(findmnt -no SOURCE /)
case "$ROOT_DEV" in
  "$DISK"p*) OS_ON_DISK=yes ;;
  *)         OS_ON_DISK=no ;;
esac

if [ "$OS_ON_DISK" = "yes" ]; then
    # Identify the rook partition: an unmounted partition of $DISK that carries no
    # filesystem (blkid reports nothing) or only stale LVM metadata. The root
    # partition is always excluded.
    ROOK_PART=""
    for part in ${DISK}p*; do
        [ -b "$part" ] || continue
        [ "$part" = "$ROOT_DEV" ] && continue
        [ -n "$(findmnt -rn -n -o TARGET --source "$part")" ] && continue
        part_type=$(blkid -o value -s TYPE "$part" 2>/dev/null | head -n1 || true)
        if [ -z "$part_type" ] || [ "$part_type" = "LVM2_member" ]; then
            if [ -n "$ROOK_PART" ]; then
                echo "error: multiple unmounted candidate partitions on $DISK: $ROOK_PART $part" >&2
                exit 1
            fi
            ROOK_PART=$part
        fi
    done

    if [ -z "$ROOK_PART" ]; then
        echo "error: no unmounted rook partition found on $DISK (OS runs from $ROOT_DEV); refusing to continue" >&2
        exit 1
    fi

    TARGET="$ROOK_PART"
    echo "OS runs from $ROOT_DEV on $DISK; wiping only $TARGET"
else
    TARGET="$DISK"
    echo "OS runs from $ROOT_DEV, not from $DISK; zapping whole disk"
fi

if [ "$OS_ON_DISK" = "no" ]; then
    # Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
    sgdisk --zap-all "$DISK" >/dev/null
fi

# Wipe a large portion of the beginning of the target to remove LVM metadata that may be present
dd if=/dev/zero of="$TARGET" bs=1M count=100 oflag=direct,dsync status=none

# SSDs may be better cleaned with blkdiscard instead of dd
blkdiscard "$TARGET"

# Inform the OS of partition table changes
partprobe "$DISK"

# Remove rook directory
rm -rf /var/lib/rook
