#!/bin/bash

set -euo pipefail

# Remove swap entry from /etc/fstab
echo "Removing swap entry from /etc/fstab..."
sed -i '/swap/d' /etc/fstab

# Disable the swap service
echo "Disabling swap service..."
swapoff -a

# Confirm swap is disabled
if grep -q "swap" /proc/swaps; then
    echo "Swap is still enabled. Please check and try again."
    exit 1
else
    echo "Swap is disabled."
fi

echo "Swap permanently disabled."