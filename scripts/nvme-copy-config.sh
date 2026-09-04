#!/bin/bash

set -euo pipefail

mkdir -p /mnt/sdfat
mount /dev/mmcblk0p1 /mnt/sdfat

mkdir -p /mnt/nvfat
mount /dev/nvme0n1p1 /mnt/nvfat

cp /mnt/sdfat/user-data /mnt/sdfat/network-config /mnt/nvfat/

umount /mnt/sdfat
umount /mnt/nvfat