#!/bin/bash

set -euo pipefail

if [[ -z "${TALOS_CONTROLPLANE:-}" ]]; then
  echo "Error: TALOS_CONTROLPLANE environment variable is required." >&2
  exit 1
fi
if [[ -z "${TARGET_NODE:-}" ]]; then
  echo "Error: TARGET_NODE environment variable is required." >&2
  exit 1
fi

CURRENT_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
if [[ "$CURRENT_SERVER" != "https://${TALOS_CONTROLPLANE}:6443" ]]; then
  echo "Error: Current kubectl context server ($CURRENT_SERVER) does not match TALOS_CONTROLPLANE ($TALOS_CONTROLPLANE)" >&2
  exit 1
fi
CURRENT_TALOS=$(talosctl config info -o json | jq -r '.endpoints[0]')
if [[ "$CURRENT_TALOS" != "$TALOS_CONTROLPLANE" ]]; then
  echo "Error: Current talosctl endpoint ($CURRENT_TALOS) does not match TALOS_CONTROLPLANE ($TALOS_CONTROLPLANE)" >&2
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

KUBELET_KUBECONFIG_ARGS="--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
KUBELET_CONFIG_ARGS="--config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///run/containerd/containerd.sock --cgroup-driver=systemd"
KUBELET_EXTRA_ARGS=${KUBELET_EXTRA_ARGS:-""}
cat > "$CONFIG/20-talos.conf" <<EOT
[Service]
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet ${KUBELET_KUBECONFIG_ARGS} ${KUBELET_CONFIG_ARGS} ${KUBELET_EXTRA_ARGS}
EOT

echo "Copying config files to remote node: $TARGET_NODE"
ssh root@$TARGET_NODE "mkdir -p /etc/kubernetes/pki /var/lib/kubelet /usr/lib/systemd/system/kubelet.service.d"
scp "$CONFIG/bootstrap-kubelet.conf" root@$TARGET_NODE:/etc/kubernetes/bootstrap-kubelet.conf
scp "$CONFIG/kubelet.conf" root@$TARGET_NODE:/etc/kubernetes/kubelet.conf
scp "$CONFIG/ca.crt" root@$TARGET_NODE:/etc/kubernetes/pki/ca.crt
scp "$CONFIG/config.yaml" root@$TARGET_NODE:/var/lib/kubelet/config.yaml
scp "$CONFIG/20-talos.conf" root@$TARGET_NODE:/usr/lib/systemd/system/kubelet.service.d/20-talos.conf
echo "Config files copied successfully to $TARGET_NODE"

echo "Patching kubeconfig-in-cluster ConfigMap to use ${TALOS_CONTROLPLANE}:6443 ..."
kubectl -n kube-system get configmap kubeconfig-in-cluster -o yaml \
  | sed "s|https://127.0.0.1:7445|https://${TALOS_CONTROLPLANE}:6443|g" \
  | kubectl apply -f -
echo "ConfigMap patched successfully."