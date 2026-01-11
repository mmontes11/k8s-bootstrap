#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

# see:
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
# https://docs.docker.com/engine/install/ubuntu/

ARCH=$(get_architecture)
if [ -z "$ARCH" ]; then
  echo "Architecture not supported"
  exit 1
fi

CONTAINERD_VERSION=${CONTAINERD_VERSION:-2.2.1-1~ubuntu.24.04~noble}

if [ -n "${UPGRADE:-}" ]; then
  echo "🛑 Stopping kubelet..."
  systemctl stop kubelet || true
  echo "🛑 Stopping containerd..."
  systemctl stop containerd || true
fi

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "📦 Installing containerd.io version: ${CONTAINERD_VERSION}"
apt update
apt install -y --allow-change-held-packages "containerd.io=${CONTAINERD_VERSION}"
apt-mark hold containerd.io || true

mkdir -p /etc/containerd
cp config/containerd.toml /etc/containerd/config.toml

echo "🚀 Starting containerd..."
systemctl daemon-reload
systemctl restart containerd