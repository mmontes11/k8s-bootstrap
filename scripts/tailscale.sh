#!/bin/bash

apt update
apt install tailscale

tailscale up --accept-dns=false
cat << EOF

Your tailscale IP is: $(tailscale ip -4)

EOF