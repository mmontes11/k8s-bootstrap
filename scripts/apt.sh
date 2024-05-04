#!/bin/bash

set -euo pipefail

apt update
apt upgrade -y

apt install \
  apt-transport-https \
  ca-certificates \
  conntrack \
  curl \
  gawk \
  git \
  gnupg \
  gpg \
  htop \
  ipset \
  ipvsadm  \
  jq \
  libseccomp2 \
  linux-raspi \
  lsb-release \
  net-tools \
  nfs-common \
  openssh-server \
  openssl \
  sed \
  socat \
  systemd \
  vim \
  wget \
  -y

apt autoremove -y
