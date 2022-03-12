#!/bin/bash

set -euo pipefail

helm repo add metallb https://metallb.github.io/metallb
helm repo update

# cni
helm upgrade --install weave-net ./helm/charts/weave-net -n kube-system

# metallb

# enable strict ARP
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

helm upgrade --install metallb metallb/metallb -f helm/values/metallb.yaml -n kube-system