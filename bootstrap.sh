#!/bin/bash

set -euo pipefail

helm repo add "cilium" "https://helm.cilium.io/"
helm repo update

# cilium
CILIUM_VERSION=1.11.2 
helm upgrade --install cilium cilium/cilium \
  --version $CILIUM_VERSION \
  --values helm/values/cilium.yaml \
  --namespace kube-system