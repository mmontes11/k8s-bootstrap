#!/bin/bash

apt update
apt upgrade

apt install \
  apt-transport-https \
  ca-certificate \
  conntrack \
  curl \
  gawk \
  git \
  gnupg \
  htop \
  ipset \
  ipvsadm  \
  jq \
  libseccomp2 \
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
