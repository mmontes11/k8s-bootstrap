#!/bin/bash

set -euo pipefail

DEV="${1:-/dev/nvme0n1}"
NAS="${2:-10.0.0.50:/volume1/images}"
IMG="${3:-raspi-storage.img.zst}"

mkdir -p /mnt/nas
mount -t nfs ${NAS} /mnt/nas

# NVMe read → compress (all cores) → push over NFS
dd if=${DEV} bs=4M status=progress | zstd -T0 -o /mnt/nas/${IMG} 
sha256sum /mnt/nas/${IMG} | tee /mnt/nas/${IMG}.sha256
sync

umount /mnt/nas