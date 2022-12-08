#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

# see:
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/
# https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md#prerequisite

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

# sysctl params required by setup, params persist across reboots
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# local hosts
cat <<EOT >> /etc/hosts
192.168.0.110 k8s-master.local
192.168.0.111 k8s-worker0.local
192.168.0.112 k8s-worker1.local
192.168.0.120 nas.local
EOT