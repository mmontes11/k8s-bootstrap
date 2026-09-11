#!/bin/bash

set -euo pipefail

# Re-copy the current control-plane certificates and kubeconfigs to a worker
# node that was provisioned with scripts/talos-config.sh.
#
# scripts/talos-config.sh copies the control-plane kubelet kubeconfig, the
# bootstrap kubeconfig and the CA to the node at join time. If those drift
# (for example after a Talos upgrade that re-issued the control-plane
# certificates), this script re-pulls the current versions from the
# control-plane, installs them on the target node and restarts the kubelet.
#
# NOTE: this does NOT renew the node's own TLS-bootstrap client certificate
# (the one the kubelet minted on join, stored in
# /var/lib/kubelet/pki/kubelet-client-current.pem). That certificate is the
# node's own identity, expires on its own one-year schedule and is what
# KubeClientCertificateExpiration usually refers to. Renew it with:
#
#   TARGET_NODE=<host> ./scripts/kubelet-client-rotate.sh
#
# Prerequisites:
#   - kubectl and talosctl are both pointed at $TALOS_CONTROLPLANE.
#   - The control-plane certificates have already been rotated.
#
# Usage:
#   TALOS_CONTROLPLANE=<host> TARGET_NODE=<host> ./scripts/talos-rotate.sh

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
trap 'rm -rf "$CONFIG"' EXIT
echo "Using temporary directory: $CONFIG"

# Re-pull the same certificate material that scripts/talos-config.sh installs
# at provision time.
echo "Pulling current certificate material from $TALOS_CONTROLPLANE ..."
talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/kubeconfig-kubelet > "$CONFIG/kubelet.conf"
talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/bootstrap-kubeconfig > "$CONFIG/bootstrap-kubelet.conf"
talosctl -n "$TALOS_CONTROLPLANE" cat /etc/kubernetes/pki/ca.crt > "$CONFIG/ca.crt"

sed -i "/server:/ s|:.*|: https://${TALOS_CONTROLPLANE}:6443|g" \
  "$CONFIG/kubelet.conf" \
  "$CONFIG/bootstrap-kubelet.conf"

# Best-effort: print the control-plane kubelet client certificate validity so
# the operator can confirm the certificate actually changed.
if CLIENT_CERT_B64=$(awk '/client-certificate-data:/ {print $2; exit}' "$CONFIG/kubelet.conf"); then
  if [[ -n "${CLIENT_CERT_B64:-}" ]]; then
    echo "Control-plane kubelet client certificate:"
    echo "$CLIENT_CERT_B64" | base64 -d | openssl x509 -noout -subject -dates \
      || echo "  (could not parse the client certificate)"
  fi
fi

echo "Installing rotated certificate material on $TARGET_NODE ..."
ssh root@$TARGET_NODE "mkdir -p /etc/kubernetes/pki"
scp "$CONFIG/bootstrap-kubelet.conf" root@$TARGET_NODE:/etc/kubernetes/bootstrap-kubelet.conf
scp "$CONFIG/kubelet.conf" root@$TARGET_NODE:/etc/kubernetes/kubelet.conf
scp "$CONFIG/ca.crt" root@$TARGET_NODE:/etc/kubernetes/pki/ca.crt

echo "Restarting kubelet on $TARGET_NODE ..."
ssh root@$TARGET_NODE "systemctl restart kubelet && systemctl is-active kubelet"

echo "Certificate rotation completed for $TARGET_NODE."
