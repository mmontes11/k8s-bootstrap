#!/bin/bash

set -euo pipefail

function get_user() {
  USER=$(who am i | awk '{print $1}')
  echo $USER
}

function get_user_home() {
  USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
  echo $USER_HOME
}

function get_architecture() {
  ARCH=$(uname -m)
  if [ $ARCH == "x86_64" ]; then
    echo "amd64"
  elif [ $ARCH == "aarch64" ]; then
    echo "arm64"
  elif [[ $ARCH == arm* ]]; then
    echo "arm"
  else
    echo ""
  fi
}

function install_bin() {
  BIN=$1
  URL=$2
  echo "Installing binary '$BIN'"
  echo "Getting release from '$URL'..."

  curl -Lo $BIN $URL
  chmod +x $BIN
  mv $BIN /usr/local/bin/$BIN
}

function install_tar() {
  BIN=$1
  URL=$2
  TAR_DIR=$3
  echo "Installing binary '$BIN' from tar.gz"
  echo "Getting release from '$URL'..."

  TMP_TAR=/tmp/tar
  TMP_BIN=/tmp/$BIN
  mkdir -p $TMP_TAR
  mkdir -p $TMP_BIN

  curl -Lo $TMP_TAR/$BIN $URL
  tar -C $TMP_BIN -zxvf $TMP_TAR/$BIN

  BIN_PATH=/tmp/$BIN/$BIN
  if [ ! -z $TAR_DIR ]; then
    BIN_PATH=/tmp/$BIN/$TAR_DIR/$BIN
  fi

  chmod +x $BIN_PATH
  mv $BIN_PATH /usr/local/bin/$BIN
  rm -rf $TMP_TAR $TMP_BIN
}

function add_host() {
  IP=$1
  HOSTNAME=$2
  HOSTS_FILE=$3
  if [ -n "$(grep $HOSTNAME $HOSTS_FILE)" ]; then
    echo "\"$HOSTNAME\" host already exists in $HOSTS_FILE"
  else
    echo "Adding \"$HOSTNAME\" to $HOSTS_FILE";
    sudo -- sh -c -e "echo '\n# k8s-bootstrap\n$IP\t$HOSTNAME' >> $HOSTS_FILE";
  fi  
}

check_variable() {
  if [ -z "${!1}" ]; then
    echo "Environment variable \"$1\" not set"
    exit 1
  fi
}
