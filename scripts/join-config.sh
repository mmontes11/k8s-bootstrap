#!/bin/bash

set -euo pipefail

API_SERVER_ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' | sed s/'http[s]\?:\/\/'//)
TOKEN=$(kubeadm token create)
CA_CERT_HASH="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl ec -pubin -outform der 2>/dev/null | sha256sum | cut -d' ' -f1)"

echo "Generating kubeadm-join.yaml config..."

kubeadm-join-config --config-path ./config/kubeadm-join.compute.yaml \
  --api-server-endpoint $API_SERVER_ENDPOINT \
  --token $TOKEN \
  --ca-cert-hash $CA_CERT_HASH \
  --label-key node.mmontes.io/type \
  --label-value compute

kubeadm-join-config --config-path ./config/kubeadm-join.compute-small.yaml \
  --api-server-endpoint $API_SERVER_ENDPOINT \
  --token $TOKEN \
  --ca-cert-hash $CA_CERT_HASH \
  --label-key node.mmontes.io/type \
  --label-value compute-small

kubeadm-join-config --config-path ./config/kubeadm-join.storage.yaml \
  --api-server-endpoint $API_SERVER_ENDPOINT \
  --token $TOKEN \
  --ca-cert-hash $CA_CERT_HASH \
  --label-key node.mmontes.io/type \
  --label-value storage \
  --taint node.mmontes.io/storage

cat << EOF

Generated join configuration files: 
- 'config/kubeadm-join.compute.yaml'
- 'config/kubeadm-join.compute-small.yaml'
- 'config/kubeadm-join.storage.yaml'

Copy these file to each worker node and run this command to join the cluster:

sudo bash node.sh 'config/kubeadm-join.compute.yaml'

EOF