#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

# see:
# https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md#prerequisite
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/

# kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

modules=(
  overlay
  br_netfilter
  ip_vs
  ip_vs_rr
  ip_vs_wrr
  ip_vs_sh
  nf_conntrack
)

for i in "${!modules[@]}"; do
  modprobe -- "${modules[$i]}"
done

lsmod | grep -e overlay -e br_netfilter -e ip_vs -e nf_conntrack

# kernel parameters
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# firewall ports
ports=(
  2379
  2380
  6443
  10250
  10257
  10259
)

for i in "${!ports[@]}"; do
  PORT="${ports[$i]}"
  ufw allow "$PORT"
  ufw allow "$PORT/tcp"
  ufw allow "$PORT/udp"
done