#!/bin/bash

apt update
apt install tailscale

tailscale up --accept-dns=false
tailscale status