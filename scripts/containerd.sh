#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

ARCH=$(get_architecture)
if [ -z $ARCH ]; then
  echo "Architecture not supported"
  exit 1
fi

CONTAINERD_VERSION=1.6.12-1
NERDCTL_VERSION=1.0.0
NERCTL_URL="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

mkdir -p /etc/containerd
cp config/containerd.toml /etc/containerd/config.toml

apt update
apt install -y containerd.io=$CONTAINERD_VERSION
apt-mark hold containerd.io

install_tar nerdctl $NERCTL_URL ""