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

nodes
source ./scripts/nodes.sh

certificate signing requests
kubectl get csr \
  -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
  | xargs kubectl certificate approve

# cilium
CILIUM_VERSION=1.11.4 
helm repo add cilium https://helm.cilium.io/
helm upgrade --install \
  cilium cilium/cilium --version $CILIUM_VERSION \
  -f helm/values/cilium.yaml \
  -n kube-system
cilium status --wait

# local path provisioner
helm upgrade --install local-path-provisioner ./helm/charts/local-path-provisioner -n kube-system

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
  --branch=kubernetes-1.25 \
  --path=./clusters/production \
  --personal \
  --private=false