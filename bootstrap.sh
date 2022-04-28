#!/bin/bash

set -euo pipefail

# node labels
kubectl label node k8s-master node.mmontes.io/type=compute
kubectl label node k8s-worker0 node.mmontes.io/type=compute

# cilium
CILIUM_VERSION=1.11.4 
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium --version $CILIUM_VERSION -n kube-system

cilium status --wait

# local path provisioner
helm upgrade --install local-path-provisioner ./helm/charts/local-path-provisioner -n kube-system

# sealed secrets
kubectl create secret tls -n kube-system sealed-secrets-key --cert=certs/tls.crt --key=certs/tls.key 
kubectl label secret -n kube-system sealed-secrets-key sealedsecrets.bitnami.com/sealed-secrets-key=active

# flux 
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=k8s-infrastructure \
  --branch=main \
  --path=./clusters/production \
  --personal \
  --private=false