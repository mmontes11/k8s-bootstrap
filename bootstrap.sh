#!/bin/bash

set -euo pipefail

# cni
helm upgrade --install weave-net ./helm/charts/weave-net -n kube-system
