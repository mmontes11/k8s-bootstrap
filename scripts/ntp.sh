#!/bin/bash

set -euo pipefail

echo "Removing systemd-timesyncd..."
apt purge -y systemd-timesyncd

echo "Installing ntp..."
apt update
apt-get -y install ntpsec ntp
systemctl status ntp

echo "Checking NTP sync..."
ntpq -p
