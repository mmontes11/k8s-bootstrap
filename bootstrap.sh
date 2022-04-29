#!/bin/bash

set -euo pipefail

# node labels
kubectl label node k8s-master node.mmontes.io/type=compute --overwrite 
kubectl label node k8s-worker0 node.mmontes.io/type=compute --overwrite 

# certificate signing requests
kubectl get csr \
  -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
  | xargs kubectl certificate approve

# cilium
CILIUM_VERSION=1.11.4 
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium --version $CILIUM_VERSION -n kube-system
cilium status --wait

# coredns
kubectl apply -f manifests/configmaps/coredns.yaml
kubectl rollout restart deployment/coredns -n kube-system

# local path provisioner
helm upgrade --install local-path-provisioner ./helm/charts/local-path-provisioner -n kube-system

# sealed secrets
kubectl create secret tls \
  -n kube-system sealed-secrets-key \
  --cert=certs/tls.crt --key=certs/tls.key \
  --dry-run=client -o yaml \
  | kubectl apply -f -
kubectl label secret \
  -n kube-system sealed-secrets-key\
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