#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

# see:
# https://github.com/rook/rook/issues/1312

cat <<EOF | tee /etc/modules-load.d/rbd.conf
rbd
EOF

modprobe -- "rbd"

sysctl --system