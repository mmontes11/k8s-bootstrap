#!/bin/bash

set -euo pipefail

if [ -z "$GITHUB_USER" ]; then
  echo "Environment variable \"GITHUB_USER\" not set"
  exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
  echo "Environment variable \"GITHUB_REPO\" not set"
  exit 1
fi

# certificate signing requests
kubectl get csr \
  -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
  | xargs kubectl certificate approve

# prometheus crds (required by cilium)
kubectl apply -f \
  https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml

# cilium
CILIUM_VERSION=1.12.4
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install \
  cilium cilium/cilium --version $CILIUM_VERSION \
  -f config/cilium.yaml \
  -n kube-system

# local path provisioner
helm upgrade --install \
  local-path-provisioner \
  ./charts/local-path-provisioner \
  -f config/local-path-provisioner.yaml \
  -n kube-system

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
  --branch=main \
  --path=./clusters/production \
  --personal \
  --private=false