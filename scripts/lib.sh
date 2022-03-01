#!/bin/bash

set -euo pipefail

function ensure_env_var() {
  if [ -z $1 ]; then
    echo "Environment variable $1 is not set"
    exit 1
  fi
}

function get_user() {
  USER=$(who am i | awk '{print $1}')
  echo $USER
}

function get_user_home() {
  USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
  echo $USER_HOME
}