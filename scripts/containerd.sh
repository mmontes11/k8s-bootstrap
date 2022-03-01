#!/bin/bash

set -euo pipefail

CONTAINERD_VERSION=1.4.12
CONTAINERD_TARBALL=cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz

wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/$CONTAINERD_TARBALL

tar --no-overwrite-dir -C / -xzf $CONTAINERD_TARBALL
rm $CONTAINERD_TARBALL

mkdir -p /etc/containerd
cp config/containerd.toml /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable containerd
systemctl start containerd