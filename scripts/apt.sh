#!/bin/bash

set -euo pipefail

apt update
apt upgrade -y

apt purge -y systemd-timesyncd

apt install \
  apt-transport-https \
  ca-certificates \
  chrony \
  conntrack \
  curl \
  gawk \
  gdisk \
  git \
  gnupg \
  gpg \
  htop \
  iotop \
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
  parted \
  rpi-imager \
  sed \
  socat \
  systemd \
  vim \
  wget \
  zstd \
  -y

apt autoremove -y
