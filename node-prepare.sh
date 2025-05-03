#!/bin/bash

set -euo pipefail

#!/bin/bash

# Kubernetes-required cgroup parameters:
if grep -q "cgroup_enable=cpuset" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_enable=memory" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_memory=1" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_enable=hugetlb" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_enable=blkio" /boot/firmware/cmdline.txt &&
   # NVMe/PCIe stability parameters:
   grep -q "nvme_core.default_ps_max_latency_us=0" /boot/firmware/cmdline.txt &&
   grep -q "pcie_aspm=off" /boot/firmware/cmdline.txt &&
   grep -q "pcie_port_pm=off" /boot/firmware/cmdline.txt; then

   echo "Boot parameters already set"
else
   echo "Appending boot parameters..."
   sed -i 's|$| cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 cgroup_enable=hugetlb cgroup_enable=blkio nvme_core.default_ps_max_latency_us=0 pcie_aspm=off pcie_port_pm=off|' /boot/firmware/cmdline.txt

   echo "Boot parameters added"
fi

if [ -f "/etc/sysctl.d/60-apparmor-namespace.conf" ] &&
    grep -q "kernel.apparmor_restrict_unprivileged_userns=0" "/etc/sysctl.d/60-apparmor-namespace.conf"; then

    echo "AppArmor parameters already set"
else
    echo "kernel.apparmor_restrict_unprivileged_userns=0" \
      | tee "/etc/sysctl.d/60-apparmor-namespace.conf" >/dev/null

    echo "AppArmor parameters added"
fi
