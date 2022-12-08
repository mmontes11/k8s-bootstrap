#!/bin/bash

apt update
apt install tailscale

tailscale up --advertise-routes=192.168.0.0/16 --accept-dns=false
tailscale status