#!/bin/bash

set -euo pipefail

cat <<EOF | tee /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

# local hosts
cat <<EOT >> /etc/hosts
192.168.0.100 k8s-master.local
192.168.0.101 k8s-worker0.local
192.168.0.102 k8s-worker1.local
192.168.0.103 k8s-worker2.local
192.168.0.120 nas.local
EOT