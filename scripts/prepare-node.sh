#!/bin/bash

set -euo pipefail

if grep -q "cgroup_enable=cpuset" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_enable=memory" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_memory=1" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_enable=hugetlb" /boot/firmware/cmdline.txt &&
   grep -q "cgroup_enable=blkio" /boot/firmware/cmdline.txt; then

   echo "Boot parameters already set"
else
   echo " cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 cgroup_enable=hugetlb cgroup_enable=blkio" \
    | tee -a /boot/firmware/cmdline.txt >/dev/null

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
