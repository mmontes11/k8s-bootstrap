#!/bin/bash

set -euo pipefail

if [[ -z "${TALOS_CONTROLPLANE:-}" ]]; then
  echo "Error: TALOS_CONTROLPLANE environment variable is required." >&2
  exit 1
fi
CONFIG="./kubelet"

mkdir -p $CONFIG

talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/kubeconfig-kubelet > $CONFIG/kubelet.conf
talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/bootstrap-kubeconfig > $CONFIG/bootstrap-kubelet.conf
talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/pki/ca.crt > $CONFIG/ca.crt

sed -i "/server:/ s|:.*|: https://${TALOS_CONTROLPLANE}:6443|g" \
  $CONFIG/kubelet.conf \
  $CONFIG/bootstrap-kubelet.conf

clusterDomain=$(talosctl -n "$TALOS_CONTROLPLANE" get kubeletconfig -o jsonpath="{.spec.clusterDomain}")
clusterDNS=$(talosctl -n "$TALOS_CONTROLPLANE" get kubeletconfig -o jsonpath="{.spec.clusterDNS}")
cat > $CONFIG/config.yaml <<EOT
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
clusterDomain: "$clusterDomain"
clusterDNS: $clusterDNS
runtimeRequestTimeout: "0s"
cgroupDriver: systemd
EOT