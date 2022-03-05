#!/bin/bash

apt update

pkgs=(
  apt-transport-https
  ca-certificates
  curl
  fzf
  gawk
  git
  htop
  jq
  libseccomp2
  net-tools
  openssh-server
  openssl
  sed
  systemd
  vim
  wget
)

for i in "${!pkgs[@]}"; do
  apt install "${pkgs[$i]}" -y
done

apt autoremove -y
