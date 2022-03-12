#!/bin/bash

set -euo pipefail

helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo add metallb https://metallb.github.io/metallb
helm repo update

kubectl apply -f manifests/secrets

# cni
helm upgrade --install weave-net ./helm/charts/weave-net -n kube-system

# kube-prometheus-stack
KUBE_PROMETHEUS_STACK_VERSION=33.2.0

helm upgrade --install kube-prometheus-stack prometheus/kube-prometheus-stack \
  --version $KUBE_PROMETHEUS_STACK_VERSION -f helm/values/kube-prometheus-stack.yaml \
  -n monitoring --create-namespace

# metallb
METALLB_VERSION=0.12.1 

kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

helm upgrade --install metallb metallb/metallb \
  --version $METALLB_VERSION -f helm/values/metallb.yaml \
  -n kube-system