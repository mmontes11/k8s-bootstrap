#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

check_variable "GITHUB_USER"
check_variable "GITHUB_REPO"
check_variable "GITHUB_BRANCH"
check_variable "GITHUB_PATH"
check_variable "GITHUB_TOKEN"

# certificate signing requests
kubectl get csr \
  -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
  | xargs kubectl certificate approve

# prometheus crds (required by cilium)
PROMETHEUS_VERSION="58.3.1"
kubectl apply -f \
  https://raw.githubusercontent.com/prometheus-community/helm-charts/kube-prometheus-stack-${PROMETHEUS_VERSION}/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml

# cilium
CILIUM_VERSION=1.15.4
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install \
  cilium cilium/cilium --version $CILIUM_VERSION \
  -f config/cilium.yaml \
  -n kube-system

# local path provisioner
git clone https://github.com/rancher/local-path-provisioner.git
helm upgrade --install \
  local-path-provisioner \
  ./local-path-provisioner/deploy/chart/local-path-provisioner \
  -f config/local-path-provisioner.yaml \
  -n kube-system
rm -rf local-path-provisioner

# sealed secrets
SECRETS_NAMESPACE=secrets
kubectl create namespace $SECRETS_NAMESPACE
kubectl create secret tls \
  -n $SECRETS_NAMESPACE \
  sealed-secrets-key \
  --cert=certs/tls.crt --key=certs/tls.key \
  --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl label secret \
  -n $SECRETS_NAMESPACE \
  sealed-secrets-key \
  sealedsecrets.bitnami.com/sealed-secrets-key=active \
  --overwrite 

# flux 
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=$GITHUB_BRANCH \
  --path=$GITHUB_PATH \
  --personal \
  --private=false