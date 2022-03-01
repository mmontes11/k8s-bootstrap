#!/bin/bash

set -euo pipefail

API_SERVER_ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' | sed s/'http[s]\?:\/\/'//)
TOKEN=$(kubeadm token list -o jsonpath='{.token}')
CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | sha256sum | cut -d' ' -f1)

cat << EOF

Installation completed successfully! 🚀
Run this commands on each worker node to join the cluster:

export API_SERVER_ENDPOINT='$API_SERVER_ENDPOINT'
export TOKEN='$TOKEN'
export CA_CERT_HASH='sha256:$CA_CERT_HASH'
sudo --preserve-env bash worker.sh
EOF