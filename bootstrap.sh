#!/bin/bash

set -eo pipefail

GITHUB_USER=${GITHUB_USER:-mmontes11}
GITHUB_REPO=${GITHUB_REPO:-k8s-infrastructure }
GITHUB_BRANCH=${GITHUB_BRANCH:-v3} # TODO: update default branch to main
GITHUB_PATH=${GITHUB_PATH:-clusters/homelab}
if [ -z "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN environment variable must be provided"
  exit 1
fi

# certificate signing requests
kubectl get csr \
  -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
  | xargs -r kubectl certificate approve

# prometheus crds (required by cilium)
PROMETHEUS_VERSION="62.3.1"
kubectl apply -f \
  https://raw.githubusercontent.com/prometheus-community/helm-charts/kube-prometheus-stack-${PROMETHEUS_VERSION}/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml

# cilium
CILIUM_VERSION=1.16.1
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install \
  cilium cilium/cilium --version $CILIUM_VERSION \
  -f config/cilium.yaml \
  -n networking --create-namespace

# local path provisioner
LOCAL_PATH_VERSION=v0.0.29
git clone https://github.com/rancher/local-path-provisioner.git
cd local-path-provisioner
git checkout $LOCAL_PATH_VERSION
helm upgrade --install \
  local-path-provisioner \
  ./deploy/chart/local-path-provisioner \
  -f ../config/local-path-provisioner.yaml \
  -n storage --create-namespace
cd ..
rm -rf local-path-provisioner

# sealed secrets
SECRETS_NAMESPACE=secrets
kubectl create namespace $SECRETS_NAMESPACE \
  --dry-run=client -o yaml \
  | kubectl apply -f -
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