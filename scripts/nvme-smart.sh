#!/bin/bash

# Capture NVMe diagnostics for hardware fault analysis / RMA evidence:
# controller ID (model, serial, firmware), SMART health log, and error log.
#
# Usage: sudo bash scripts/nvme-smart.sh [device] [output-file]
#   device      NVMe namespace to query (default: /dev/nvme0n1)
#   output-file capture destination (default: /tmp/nvme-smart-<serial>-<timestamp>.txt)

set -euo pipefail

DEV="${1:-/dev/nvme0n1}"

SERIAL=$(nvme id-ctrl -H "$DEV" | sed -n 's/^Serial Number *: *//p')
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="${2:-/tmp/nvme-smart-${SERIAL:-unknown}-${TS}.txt}"

{
  echo "# NVMe diagnostics capture"
  echo "# host:        $(hostname)"
  echo "# device:      $DEV"
  echo "# captured at: $TS (UTC)"
  echo
  echo "## nvme id-ctrl"
  nvme id-ctrl -H "$DEV"
  echo
  echo "## nvme smart-log"
  nvme smart-log "$DEV"
  echo
  echo "## nvme smart-log (json)"
  nvme smart-log "$DEV" --output-format=json
  echo
  echo "## nvme error-log"
  nvme error-log "$DEV"
  echo
  echo "## nvme list"
  nvme list
} > "$OUT"

echo "NVMe diagnostics for $DEV captured to $OUT"
cat "$OUT"
