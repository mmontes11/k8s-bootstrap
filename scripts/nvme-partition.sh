#!/bin/bash

set -euo pipefail

DEV="${1:-/dev/nvme0n1}"

parted -s $DEV print                        # sanity check: msdos, p1 fat, p2 ext4 (small)
parted -s $DEV resizepart 2 128GiB          # grow p2's end boundary to 128GiB from the start of the disk
e2fsck -f ${DEV}p2                          # check before/during resize
resize2fs ${DEV}p2 124G                     # grow the fs to 124G inside the 128GiB partition

# Create the rook partition from the remainder of the disk. Do NOT format it:
parted -s $DEV mkpart primary 128GiB 100%
sfdisk --part-type $DEV 3 83                # explicit MBR type 0x83 "Linux" (sgdisk is GPT-only)

# Verify:
lsblk -f $DEV                               # p2 must show ext4; p3 must show NOTHING