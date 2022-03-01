#!/bin/bash

set -euox pipefail

CONTAINERD_VERSION=1.4.12

apt update
apt install libseccomp2

wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz

sudo tar --no-overwrite-dir -C / -xzf cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz

mkdir -p /etc/containerd
cp config/containerd.toml /etc/containerd/config.toml

systemctl daemon-reload
systemctl restart containerd