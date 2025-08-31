#!/bin/bash

set -euo pipefail

if [[ -z "${TALOS_CONTROLPLANE:-}" ]]; then
  echo "Error: TALOS_CONTROLPLANE environment variable is required." >&2
  exit 1
fi

CONFIG=$(mktemp -d)
echo "Using temporary directory: $CONFIG"

talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/kubeconfig-kubelet > "$CONFIG/kubelet.conf"
talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/bootstrap-kubeconfig > "$CONFIG/bootstrap-kubelet.conf"
talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/pki/ca.crt > "$CONFIG/ca.crt"

sed -i "/server:/ s|:.*|: https://${TALOS_CONTROLPLANE}:6443|g" \
  "$CONFIG/kubelet.conf" \
  "$CONFIG/bootstrap-kubelet.conf"

clusterDomain=$(talosctl -n "$TALOS_CONTROLPLANE" get kubeletconfig -o jsonpath="{.spec.clusterDomain}")
clusterDNS=$(talosctl -n "$TALOS_CONTROLPLANE" get kubeletconfig -o jsonpath="{.spec.clusterDNS}")

cat > "$CONFIG/config.yaml" <<EOT
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

if [[ -n "$TARGET_NODE" ]]; then
  echo "Copying config files to remote node: $TARGET_NODE"

  ssh root@$TARGET_NODE "mkdir -p /etc/kubernetes/pki /var/lib/kubelet"
  
  scp "$CONFIG/bootstrap-kubelet.conf" root@$TARGET_NODE:/etc/kubernetes/bootstrap-kubelet.conf
  scp "$CONFIG/kubelet.conf" root@$TARGET_NODE:/etc/kubernetes/kubelet.conf
  scp "$CONFIG/ca.crt" root@$TARGET_NODE:/etc/kubernetes/pki/ca.crt
  scp "$CONFIG/config.yaml" root@$TARGET_NODE:/var/lib/kubelet/config.yaml

  echo "Config files copied successfully to $TARGET_NODE"
fi