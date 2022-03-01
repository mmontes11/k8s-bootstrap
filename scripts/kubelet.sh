#!/bin/bash

set -euox pipefail

cp config/containerd.conf /etc/systemd/system/kubelet.service.d/0-containerd.conf
systemctl daemon-reload
systemctl restart kubelet