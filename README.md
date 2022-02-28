# 🚀 k8s-infrastructure
Kubernetes bootstrapping and core infrastructure for my personal Raspberry Pi cluster.

### Installation

Setup the controlplane on the master node by running:
```bash
sudo bash master.sh
```

Using the output of the previous command, set this variables on the worker node:
```bash
export API_SERVER_ENDPOINT=<API_SERVER_ENDPOINT>
export TOKEN=<TOKEN>
export DISCOVERY_TOKEN_HASH=<DISCOVERY_TOKEN_HASH>
``` 

Join the cluster and setup the worker node:
```bash
sudo --preserve-env bash worker.sh
``` 