#!/bin/bash

set -euo pipefail

source ./scripts/lib.sh

function setup_kubeconfig() {
  USER=$1
  USER_HOME=$2
  echo $USER
  echo $USER_HOME

  mkdir -p $USER_HOME/.kube
  cp /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  chown $(id -u $USER):$(id -g $USER) $USER_HOME/.kube/config

  cp config/.kubectl $USER_HOME/.kubectl
  source $USER_HOME/.kubectl
  cat $USER_HOME/.kubectl >> $USER_HOME/.bashrc
}

setup_kubeconfig root /root
setup_kubeconfig $(get_user) $(get_user_home)