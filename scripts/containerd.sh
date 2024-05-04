#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

# see:
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/

ARCH=$(get_architecture)
if [ -z $ARCH ]; then
  echo "Architecture not supported"
  exit 1
fi

CONTAINERD_VERSION=1.6.31-1
  
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y containerd.io=$CONTAINERD_VERSION
apt-mark hold containerd.io

mkdir -p /etc/containerd
cp config/containerd.toml /etc/containerd/config.toml

systemctl restart containerd