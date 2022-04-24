# 🚀 k8s-bootstrap
Kubernetes cluster bootstrapping using [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), [cilium](https://cilium.io/) and [flux](https://fluxcd.io).

### Prerequisites

Make sure that the following cgroups are configured in both master and worker nodes:
```text
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 cgroup_enable=hugetlb
``` 

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
