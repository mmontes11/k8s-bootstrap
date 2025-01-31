#!/bin/bash

set -euo pipefail

echo "Removing systemd-timesyncd..."
apt purge systemd-timesyncd

echo "Installing ntp..."
apt update
apt-get install ntpsec ntp
systemctl status ntp

echo "Checking NTP sync..."
ntpq -p