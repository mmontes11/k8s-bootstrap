#!/bin/bash

set -euo pipefail

DEV="${1:-/dev/nvme0n1}"

parted -s $DEV print                        # sanity check: GPT, p1 fat, p2 ext4 (small)
parted -s $DEV resizepart 2 128GiB          # grow p2's end boundary to 128GiB from the start of the disk
e2fsck -f ${DEV}p2                          # check before/during resize
resize2fs ${DEV}p2 124G                     # grow the fs to 124G inside the 128GiB partition

# Create the rook partition from the remainder of the disk. Do NOT format it:
parted -s $DEV mkpart rook 128GiB 100%
sgdisk -t 3:8300 $DEV                       # explicit "Linux filesystem" partition type

# Verify:
parted -s $DEV print
blkid ${DEV}p2 ${DEV}p3                     # p2 must show ext4; p3 must show NOTHING