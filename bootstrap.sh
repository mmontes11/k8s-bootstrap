#!/bin/bash

set -euo pipefail

# helm repo add nfs-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
# helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server
# helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard
# helm repo add prometheus https://prometheus-community.github.io/helm-charts
# helm repo add metallb https://metallb.github.io/metallb
# helm repo add traefik https://helm.traefik.io/traefik
# helm repo update

# kubectl apply -f manifests/secrets

# # nfs provisioner
# NFS_PROVISIONER_VERSION=4.0.16
# helm upgrade --install nfs-provisioner nfs-provisioner/nfs-subdir-external-provisioner \
#   --version=$NFS_PROVISIONER_VERSION -f helm/values/nfs-provisioner.yaml \
#   -n kube-system 

# # metallb
# kubectl get configmap kube-proxy -n kube-system -o yaml | \
# sed -e "s/strictARP: false/strictARP: true/" | \
# kubectl apply -f - -n kube-system

# METALLB_VERSION=0.12.1 
# helm upgrade --install metallb metallb/metallb \
#   --version $METALLB_VERSION -f helm/values/metallb.yaml \
#   -n kube-system

# # traefik
# TRAEFIK_VERSION=10.15.0
# helm upgrade --install traefik traefik/traefik \
#   --version $TRAEFIK_VERSION -f helm/values/traefik.yaml \
#   -n kube-system

# kubectl apply -f manifests/ingressroutes

# cni
helm upgrade --install weave-net ./helm/charts/weave-net -n kube-system

# local path provisioner
helm upgrade --install local-path-provisioner ./helm/charts/local-path-provisioner -n kube-system

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=k8s-infrastructure \
  --branch=main \
  --path=./clusters/mmontes-dev \
  --personal \
  --private=false