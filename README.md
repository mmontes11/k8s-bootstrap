# 🚀 k8s-infrastructure
Kubernetes bootstrapping and core infrastructure for my personal Raspberry Pi cluster.

### Installation

Setup the controlplane on the master node by running:
```bash
sudo bash master.sh
```

Copy the generated configuration `config/kubeadm-join.yaml` to each worker node and run this command to join the cluster:
```bash
sudo bash worker.sh 
``` 

Run this on the controlplane node for bootstrapping the core infrastructure:
```bash
./bootstrap.sh
``` 