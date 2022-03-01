#!/bin/bash

set -euox pipefail

source ./scripts/lib.sh

USER=$(get_user)
USER_HOME=$(get_user_home)

mkdir -p $USER_HOME/.kube
cp /etc/kubernetes/admin.conf $USER_HOME/.kube/config
chown $(id -u $USER):$(id -g $USER) $USER_HOME/.kube/config

cp config/.kubectl $USER_HOME/.kubectl
source $USER_HOME/.kubectl
cat $USER_HOME/.kubectl >> $USER_HOME/.bashrc