#!/bin/bash

set -euo pipefail

# Renew the kubelet client certificate on a worker node that was provisioned
# with scripts/talos-config.sh.
#
# Background
# ----------
# When a worker node joins, its kubelet performs TLS bootstrap and mints its OWN
# node client certificate (subject O=system:nodes, CN=system:node:<name>), signed
# by the cluster CA. That certificate -- together with its private key -- is stored
# combined in /var/lib/kubelet/pki/kubelet-client-current.pem and is valid for one
# year.
#
# This certificate is NOT a copy of the control-plane certificate and does not
# track control-plane certificate rotations. It is the node's own identity, and it
# expires on its own schedule. On some kubelet versions the kubelet does not rotate
# it on its own (the serving certificate, stored the same way, IS rotated; the
# client certificate is not). When the client certificate expires the kubelet can
# no longer authenticate to the API server: the node goes NotReady and
# KubeClientCertificateExpiration fires against the control-plane.
#
# What this script does
# ---------------------
# It renews that client certificate through the Certificates API, reusing the
# node's existing private key and subject (both embedded in the certificate
# request). It then approves the request explicitly and installs the signed
# certificate on the node in the same combined file layout the node was
# provisioned with, and restarts the kubelet so it presents the fresh
# certificate.
#
# Note on approval: the built-in node client auto-approver only fires for a
# request submitted by the node's own identity. A request created on the node's
# behalf by an operator's kubectl is NOT auto-approved, so this script approves
# it explicitly (kubectl certificate approve). Reusing the node's existing key is
# what makes the signed certificate a valid renewal of that node's identity.
#
# The private key never leaves the node. Only the public certificate request and
# the resulting public certificate are copied to the workstation.
#
# Idempotent: if the current client certificate is valid for more than SKIP_DAYS
# the node is left untouched.
#
# Prerequisites
# -------------
#   - kubectl pointed at the cluster, with permission to create, read and
#     approve certificatesigningrequests (cluster-admin, or a role granting
#     those verbs on certificatesigningrequests / certificatesigningrequests/approve).
#   - Passwordless root ssh to the target node.
#   - The node is currently a known node object in the cluster.
#
# Usage
# -----
#   TARGET_NODE=<host> [NODE_NAME=<k8s-node-name>] [SKIP_DAYS=30] [DRY_RUN=0] \
#     ./scripts/kubelet-client-rotate.sh
#
#   NODE_NAME defaults to the node's hostname (usually the same as the k8s node
#   name). DRY_RUN=1 still submits (and then deletes) a certificate request and
#   verifies it gets signed, but does not install the new certificate or restart
#   the kubelet. Use it to validate the mechanism on a node first.

usage() {
  cat <<'EOF'
Usage:
  TARGET_NODE=<host> [NODE_NAME=<name>] [SKIP_DAYS=30] [DRY_RUN=0] \
    ./scripts/kubelet-client-rotate.sh

Environment:
  TARGET_NODE   (required) Hostname/IP of the worker node to renew (ssh target).
  NODE_NAME     (optional) k8s node name; defaults to the node's hostname.
  SKIP_DAYS     (optional) Skip if the current client cert is valid for more than
                  this many days (default: 30).
  DRY_RUN       (optional) 1 = validate (submit+sign, then delete the request)
                  without installing or restarting (default: 0).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TARGET_NODE="${TARGET_NODE:-}"
NODE_NAME="${NODE_NAME:-}"
SKIP_DAYS="${SKIP_DAYS:-30}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -z "$TARGET_NODE" ]]; then
  usage
  echo "Error: TARGET_NODE environment variable is required." >&2
  exit 1
fi

# --- helpers -----------------------------------------------------------------

ssh_node() {
  ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no \
    "root@${TARGET_NODE}" "$@"
}

error() {
  echo "Error: $*" >&2
  exit 1
}

# --- 0) kubectl must reach the cluster ---------------------------------------

kubectl version --client >/dev/null 2>&1 || error "kubectl is not installed."
kubectl get nodes >/dev/null 2>&1 || error "kubectl cannot reach the cluster (check your context)."

# --- 1) resolve the k8s node name --------------------------------------------

if [[ -z "$NODE_NAME" ]]; then
  NODE_NAME="$(ssh_node 'hostname')"
fi
NODE_NAME="${NODE_NAME:-}"
[[ -n "$NODE_NAME" ]] || error "could not determine the node name (set NODE_NAME)."

if ! kubectl get node "$NODE_NAME" >/dev/null 2>&1; then
  error "node '$NODE_NAME' is not registered in the cluster (kubectl)."
fi

CLIENT_PEM="/var/lib/kubelet/pki/kubelet-client-current.pem"

echo "Node:        $NODE_NAME ($TARGET_NODE)"
echo "Client cert: $CLIENT_PEM"

# --- 2) idempotency: skip if the current client cert is still fresh ----------

FRESH="$(ssh_node "test -f '$CLIENT_PEM' && openssl x509 -in '$CLIENT_PEM' -noout -checkend $((SKIP_DAYS * 86400)) >/dev/null 2>&1 && echo yes || echo no")"
if [[ "$FRESH" == "yes" ]]; then
  echo "Client certificate is valid for more than ${SKIP_DAYS} days. Nothing to do."
  echo "Current expiry:"
  ssh_node "openssl x509 -in '$CLIENT_PEM' -noout -subject -dates"
  exit 0
fi

# show what we are renewing
echo "Current client certificate:"
ssh_node "openssl x509 -in '$CLIENT_PEM' -noout -subject -dates"

# --- 3) on the node: keep the key, build a renewal CSR with the same key ------

WORKDIR="$(mktemp -d)"
REMOTE_WORK="$(ssh_node 'mktemp -d -t kubelet-client-rotate.XXXXXX')" || error "could not create a temp dir on the node."

ssh_node bash -s -- "$REMOTE_WORK" <<'REMOTE_SETUP' || error "failed to build the renewal certificate request on the node."
  set -euo pipefail
  remote_work="$1"
  client_pem=/var/lib/kubelet/pki/kubelet-client-current.pem

  # current subject, RFC2253 form: CN=system:node:compute-0,O=system:nodes
  subj="$(openssl x509 -in "$client_pem" -noout -subject -nameopt RFC2253 | sed 's/^subject=//')"
  cn="$(printf '%s' "$subj" | tr ',' '\n' | sed -n 's/^CN=//p' | head -1)"
  o="$(printf '%s'  "$subj" | tr ',' '\n' | sed -n 's/^O=//p'  | head -1)"
  : "${cn:=system:node:$(hostname)}"
  : "${o:=system:nodes}"
  printf '%s' "$cn" > "$remote_work/cn"
  printf '%s' "$o"  > "$remote_work/org"

  # extract the private key (stays on the node)
  awk '/PRIVATE KEY/{f=1} f{print} /END .*PRIVATE KEY/{exit}' "$client_pem" > "$remote_work/key.pem"
  chmod 600 "$remote_work/key.pem"

  # renewal request re-using the same key and the same subject (canonical form)
  openssl req -new -key "$remote_work/key.pem" -subj "/O=${o}/CN=${cn}" \
    -out "$remote_work/renewal.csr"
REMOTE_SETUP

scp -q "root@${TARGET_NODE}:${REMOTE_WORK}/renewal.csr" "$WORKDIR/renewal.csr"
scp -q "root@${TARGET_NODE}:${REMOTE_WORK}/cn" "$WORKDIR/cn"
scp -q "root@${TARGET_NODE}:${REMOTE_WORK}/org" "$WORKDIR/org"

CN="$(cat "$WORKDIR/cn")"
ORG="$(cat "$WORKDIR/org")"
CN="${CN:-system:node:$NODE_NAME}"
ORG="${ORG:-system:nodes}"

echo "Renewal subject: CN=${CN}, O=${ORG}"

# --- 4) submit the certificate request to the cluster ------------------------

CSR_NAME="kubelet-client-$(printf '%s' "$NODE_NAME" | tr -c 'a-z0-9-' '-')-$(date +%s)"
REQUEST_B64="$(base64 < "$WORKDIR/renewal.csr" | tr -d '\n')"

# The subject (O=system:nodes, CN=system:node:<name>) is already embedded in the
# certificate request PEM, so it must NOT be repeated here -- the
# CertificateSigningRequestSpec has no "subject" field and the apiserver rejects
# the manifest if one is present.
cat > "$WORKDIR/csr.yaml" <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CSR_NAME
spec:
  request: $REQUEST_B64
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
EOF

echo "Submitting certificate request $CSR_NAME ..."
kubectl apply -f "$WORKDIR/csr.yaml" >/dev/null

# --- 5) approve the request and wait for it to be signed ---------------------

# The built-in node client auto-approver only fires for a request submitted by
# the node's own identity; one created by an operator's kubectl is not, so we
# approve it explicitly. Reusing the node's key makes the signed certificate a
# valid renewal of that node's identity.
echo "Approving certificate request $CSR_NAME ..."
kubectl certificate approve "$CSR_NAME" >/dev/null 2>&1 || \
  error "could not approve CSR $CSR_NAME (needs the 'approve' verb on certificatesigningrequests)."

echo "Waiting for $CSR_NAME to be signed ..."
CERT_B64=""
for _ in $(seq 1 60); do
  CERT_B64="$(kubectl get csr "$CSR_NAME" -o jsonpath='{.status.certificate}' 2>/dev/null || true)"
  [[ -n "$CERT_B64" ]] && break
  sleep 1
done

# if the signer refused (e.g. key/subject mismatch), surface the reason
if [[ -z "$CERT_B64" ]]; then
  kubectl get csr "$CSR_NAME" -o json 2>/dev/null | \
    jq -r '.status.conditions[]? | "\(.type): \(.reason) - \(.message)"' 2>/dev/null || true
fi
[[ -n "$CERT_B64" ]] || error "CSR $CSR_NAME was not signed in time."

printf '%s' "$CERT_B64" | base64 -d > "$WORKDIR/new-cert.pem"

echo "New client certificate:"
openssl x509 -in "$WORKDIR/new-cert.pem" -noout -subject -dates

# --- DRY_RUN: validate only, then clean up -----------------------------------

if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY_RUN=1: new certificate was signed successfully. Not installing; leaving the node untouched."
  kubectl delete csr "$CSR_NAME" --ignore-not-found >/dev/null 2>&1 || true
  exit 0
fi

# --- 6) install the new certificate on the node and restart the kubelet ------

TS="$(date +%Y-%m-%d-%H-%M-%S)"
NEW_FILE="/var/lib/kubelet/pki/kubelet-client-${TS}.pem"

echo "Installing $NEW_FILE on $TARGET_NODE ..."
scp -q "$WORKDIR/new-cert.pem" "root@${TARGET_NODE}:${REMOTE_WORK}/new-cert.pem"

ssh_node bash -s -- "$REMOTE_WORK" "$NEW_FILE" <<'REMOTE_INSTALL' || error "failed to install the new certificate on the node."
  set -euo pipefail
  remote_work="$1"; new_file="$2"

  # same combined layout the node was provisioned with: cert + key
  cat "$remote_work/new-cert.pem" "$remote_work/key.pem" > "$new_file"
  chmod 600 "$new_file"

  # point the current symlink at the new combined file
  ln -sfn "$new_file" /var/lib/kubelet/pki/kubelet-client-current.pem

  # restart the kubelet so it presents the new certificate
  systemctl restart kubelet
  sleep 3
  echo "kubelet active: $(systemctl is-active kubelet)"

  echo "Installed client certificate:"
  openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -subject -dates

  # shred the temp copy of the private key (the temp dir is left in /tmp)
  shred -u "$remote_work/key.pem" 2>/dev/null || rm -f "$remote_work/key.pem"
REMOTE_INSTALL

# --- 7) confirm the node is Ready and tidy up the certificate request --------

echo "Waiting for node $NODE_NAME to be Ready ..."
for _ in $(seq 1 30); do
  if kubectl get node "$NODE_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then
    break
  fi
  sleep 2
done
kubectl get node "$NODE_NAME"

kubectl delete csr "$CSR_NAME" --ignore-not-found >/dev/null 2>&1 || true

echo "Done. Renewed the kubelet client certificate on $NODE_NAME."
