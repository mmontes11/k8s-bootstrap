#!/bin/bash

set -euo pipefail

DEV="${1:-/dev/nvme0n1}"
NAS="${2:-10.0.0.50:/volume1/images}"
IMG="${3:-raspi-storage.img.zst}"

mkdir -p /mnt/nas
mount -t nfs ${NAS} /mnt/nas

sha256sum -c /mnt/nas/${IMG}.sha256
# NFS read → decompress (all cores) → NVMe write
zstd -v -dc /mnt/nas/${IMG} | dd of=${DEV} bs=4M status=progress
sync

umount /mnt/nas