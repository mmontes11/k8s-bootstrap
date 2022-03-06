#!/bin/bash

apt update

pkgs=(
  apt-transport-https
  ca-certificates
  conntrack
  curl
  fzf
  gawk
  git
  gnupg
  htop
  jq
  libseccomp2
  lsb-release
  net-tools
  openssh-server
  openssl
  sed
  socat
  systemd
  vim
  wget
)

for i in "${!pkgs[@]}"; do
  apt install "${pkgs[$i]}" -y
done

apt autoremove -y