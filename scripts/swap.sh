#!/bin/bash

set -euo pipefail

echo "Removing swap entry from /etc/fstab..."
sed -i '/swap/d' /etc/fstab

echo "Disabling swap service..."
swapoff -a

if grep -q "swap" /proc/swaps; then
    echo "Swap is still enabled. Please check and try again."
    exit 1
else
    echo "Swap is disabled."
fi

echo "Swap permanently disabled."