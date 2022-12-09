#!/bin/bash

set -euo pipefail

mkdir -p /etc/rancher/k3s
cp config/k3s.yaml /etc/rancher/k3s/config.yaml

export INSTALL_K3S_VERSION=v1.25.4+k3s1
curl -sfL https://get.k3s.io | sh -s -

mkdir ~/.kube
cp /etc/rancher/k3s/config.yaml ~/.kube/config