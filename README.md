# 🚀 k8s-bootstrap
Kubernetes cluster provision with [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) and infrastructure bootstrapping using [Flux](https://fluxcd.io/docs/)

### Installation

Setup the controlplane on the master node by running:
```bash
sudo bash master.sh
```

Copy the generated configuration `config/kubeadm-join.yaml` to each worker node and run this command to join the cluster:
```bash
sudo bash worker.sh 
``` 

Run this on the controlplane node for bootstrapping the infrastructure:
```bash
./bootstrap.sh
``` 
