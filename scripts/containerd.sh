#!/bin/bash

set -euo pipefail

CONTAINERD_VERSION=1.5.11-1 

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install containerd.io=$CONTAINERD_VERSION

mkdir -p /etc/containerd
cp config/containerd.toml /etc/containerd/config.toml

systemctl restart containerd