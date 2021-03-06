#!/bin/bash

set -euo pipefail

# nodes
source ./scripts/nodes.sh

# certificate signing requests
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
kubectl create secret tls \
  -n kube-system sealed-secrets-key \
  --cert=certs/tls.crt --key=certs/tls.key \
  --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl label secret \
  -n kube-system sealed-secrets-key \
   sealedsecrets.bitnami.com/sealed-secrets-key=active \
  --overwrite 

# flux 
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=k8s-infrastructure \
  --branch=main \
  --path=./clusters/production \
  --personal \
  --private=false