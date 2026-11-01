#!/bin/bash

set -euo pipefail

apt update
apt upgrade -y

apt purge -y systemd-timesyncd

pkgs=(
  apt-transport-https
  ca-certificates
  chrony
  conntrack
  curl
  gawk
  gdisk
  git
  gnupg
  gpg
  htop
  iotop
  ipset
  ipvsadm
  jq
  libseccomp2
  lsb-release
  net-tools
  nfs-common
  openssh-server
  openssl
  parted
  sed
  socat
  systemd
  vim
  wget
  zstd
)

# Raspberry Pi-only packages (not installable on other hardware):
if is_raspberry_pi; then
  pkgs+=(linux-raspi rpi-imager)
fi

apt install -y "${pkgs[@]}"

apt autoremove -y
