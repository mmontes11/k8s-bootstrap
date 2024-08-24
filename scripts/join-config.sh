#!/bin/bash

set -euo pipefail

API_SERVER_ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' | sed s/'http[s]\?:\/\/'//)
TOKEN=$(kubeadm token list -o jsonpath='{.token}')
CA_CERT_HASH="sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl ec -pubin -outform der 2>/dev/null | sha256sum | cut -d' ' -f1)"

echo "Generating kubeadm-join.yaml config..."

cat config/kubeadm-join.tpl.yaml | \
  sed "s/{{API_SERVER_ENDPOINT}}/$API_SERVER_ENDPOINT/g" | \
  sed "s/{{TOKEN}}/$TOKEN/g" | \
  sed "s/{{CA_CERT_HASH}}/$CA_CERT_HASH/g" > config/kubeadm-join.yaml

cat << EOF

Generated join configuration file: 'config/kubeadm-join.yaml'
Copy this file to each worker node and run this command to join the cluster:

sudo bash worker.sh

EOF