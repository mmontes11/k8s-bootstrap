# Raspberry Pi 5 storage node: SD card to NVMe migration

Migrates a Raspberry Pi 5 worker/storage node from an SD-card root filesystem to the onboard
NVMe module, so the OS lives on fast, durable storage while keeping a dedicated raw
partition for the [rook-ceph](https://rook.io/) OSD.

Reference: [Install Ubuntu on the NVMe of a Raspberry Pi 5](https://wolfpaulus.com/rp5-ubuntu-cli/).

## Target layout

A 128GB NVMe module, 3 partitions (the RPi5 firmware requires a FAT32 `/boot/firmware`
partition, hence one more partition than a plain Linux install):

| Partition | Filesystem | Size   | Mount  |
|-----------|------------|--------|--------|
| `nvme0n1p1` | fat32    | 512MiB | `/boot/firmware` |
| `nvme0n1p2` | ext4     | ~124GiB | `/` |
| `nvme0n1p3` | (raw, unformatted) | remainder (~4GiB) | none — claimed by rook-ceph |

Rook consumes `nvme0n1p3`. The OS never sees `nvme0n1p3`; rook takes exclusive control of
it, exactly as it does today with the whole-disk `nvme0n1` configuration on the other nodes.

## Safety rules (read first)

1. **One node at a time.** Never migrate two storage nodes in parallel.
2. **Ceph must be `HEALTH_OK` before you start.** Check on the control plane:
   ```bash
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s
   ```
   If there is an in-flight backfill (e.g. `active+undersized+degraded+...+backfilling`
   PGs after a previous re-image), wait until all PGs are `active+clean`. Migrating a node
   while the cluster is already degraded compounds the degraded window and can leave the
   cluster in a state it cannot recover.
3. **Keep the original SD card until the node is fully back in service** (see
   [Rollback](#rollback). It is your safety net and your spare for the next node.
4. **Merge the rook device-config PR before the migrated node rejoins the cluster** (see
   [Step 7](#step-7-rook-osd-migration)). Otherwise rook still expects the old
   whole-disk `nvme0n1` and will never see `nvme0n1p3`.
5. The OS partition is sized to leave only ~4GiB for the OSD. Raise `OS_END` (and lower the
   OSD) or lower it (and grow the OSD) to taste — but decide before flashing, the numbers
   below are used consistently.

## Tools and hardware

- A second Linux machine (the "helper") with a USB NVMe enclosure, plus: `rpi-imager`,
  `parted`, `sgdisk`, `e2fsck`, `resize2fs` (the `ubuntu-image` + `parted` +
  `dosfstools` + `e2fsprogs` packages).
- Ubuntu 24.04 preinstalled server image for Raspberry Pi
  (`ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz` from the
  [Ubuntu releases](https://cdimage.ubuntu.com/releases/24.04/release/) archive, or via
  rpi-imager's built-in catalog).
- A USB-serial console for the Pi (the storage nodes have no display; you need the console
  to boot into a fresh install and set the hostname/network).

## Procedure

### Step 1 — Pre-flight on the control plane

```bash
kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s
kubectl get nodes -l node.mmontes.io/type=storage
kubectl -n storage get pods -l app=rook-ceph-osd -o wide    # note which osd pod runs on the target node
```

Note the OSD id of the target node (e.g. `osd-3` on `storage-2`). You need it for
[Step 7](#step-7-rook-osd-migration). Ceph must say `HEALTH_OK` — see safety rules.

### Step 2 — Take the node out of the cluster

On the control plane:

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```

Then power the Pi off and remove its NVMe module into the USB enclosure on the helper.

### Step 3 — Flash a fresh OS onto the NVMe

From the helper:

```bash
# Identify the raw device (lsblk). Assume /dev/nvme0n1 on the helper for the commands below.
sudo rpi-imager
```

In rpi-imager: OS → *Ubuntu 24.04 (preinstalled, Raspberry Pi)*, Storage → the NVMe device,
flash. This writes a two-partition GPT: `p1` FAT32 (boot) and `p2` ext4 (root, sized for
the image, not for the disk).

### Step 4 — Offline partition surgery (helper, NVMe not booted)

Goal: shrink/fit `p2` to end at `124GiB`, grow its ext4 to `120G`, and create the raw
rook partition `p3` from what is left. Everything here is safe because **the disk is not
being used by any running system**.

```bash
DEV=/dev/nvme0n1    # the flashed NVMe on the helper — verify with lsblk

sudo parted -s $DEV print                       # sanity check: GPT, p1 fat, p2 ext4

# Fit p2: extend (or trim) its end boundary to 124GiB from the start of the disk.
sudo parted -s $DEV resizepart 2 124GiB

# Check/ext4 before touching it (-f forces, -y answers yes to cleanups):
sudo e2fsck -f -y ${DEV}p2

# Set the ext4 to 120G. resize2fs both grows and shrinks to the requested size, so this
# one command covers whether p2 was image-sized or already expanded to the full disk.
sudo resize2fs ${DEV}p2 120G

# Create the rook partition from the remainder of the disk. Do NOT format it:
sudo parted -s $DEV mkpart rook 124GiB 100%
sudo sgdisk -t 3:8300 $DEV                      # explicit Linux filesystem partition type

# Verify:
sudo parted -s $DEV print
sudo blkid ${DEV}p2 ${DEV}p3                    # p2 must show ext4; p3 must show NOTHING
```

`blkid` printing nothing for `p3` is required: rook provisions an unformatted device
itself. If `blkid` reports a filesystem on `p3`, delete and recreate the partition.

### Step 5 — First NVMe boot on the Pi

Reinstall the NVMe, **leave the SD card out**, power on, and follow the console:

- Set the hostname (e.g. `storage-0`) and the static IP matching your inventory.
- The preinstalled image runs cloud-init on first boot. After login, verify the layout is
  intact (cloud-init must not have expanded `p2` beyond the boundary):

  ```bash
  lsblk /dev/nvme0n1
  df -h /
  blkid /dev/nvme0n1p3     # must print nothing
  ```

  `p2` must be ~124G and mounted on `/`, and `p3` unmounted. If `p2` grew over the
  boundary (p3 gone or shrunk), stop: power off, redo [Step 4](#step-4--offline-partition-surgery-helper-nvme-not-booted)
  on the helper. Booting from the original SD card is the fallback (see Rollback).

Then run the standard node preparation (works unchanged, `cmdline.txt` now lives on the
NVMe `p1`):

```bash
sudo bash node-prepare.sh
sudo reboot
```

### Step 6 — Join the cluster again

On the control plane, generate a fresh join config (requires `kubectl`/`kubeadm` for the
cluster and the `kubeadm-join-config` binary this repo builds; see `Makefile`):

```bash
./scripts/join-config.sh        # writes config/kubeadm-join.storage.yaml (token + ca-hash are fresh)
```

Copy `config/kubeadm-join.storage.yaml` to the migrated node and join:

```bash
sudo bash node.sh 'config/kubeadm-join.storage.yaml'
```

Verify on the control plane that the node is back with the right label/taint and is
`Ready`:

```bash
kubectl get nodes -l node.mmontes.io/type=storage
```

### Step 7 — Rook OSD migration

Precondition: the companion PR in `mmontes11/k8s-infrastructure`, which switches this node's
device entry from `nvme0n1` to `nvme0n1p3` in
`infrastructure/rook/rook-ceph-cluster/rook-ceph-cluster-helmrelease.yaml`, **is merged and
applied by Flux** before this step.

1. Remove the old OSD from the cluster (it ran on the now-wiped `nvme0n1` data area).
   With `size(ceph_osd_pool) = 3` and the remaining OSDs healthy, this is safe:

   ```bash
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph osd out <old-osd-id>
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph osd rm <old-osd-id>
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s
   ```

2. Rook discovers the raw `nvme0n1p3` and creates a new OSD on it. Watch it come up:

   ```bash
   kubectl -n storage get pods -l app=rook-ceph-osd -o wide
   kubectl -n storage get osds
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s   # backfilling will show, converging to HEALTH_OK
   ```

3. Wait for `HEALTH_OK` (all PGs `active+clean`) before touching the next node.

## Rollback

Before the node rejoins the cluster, data is on the two remaining OSDs at full
redundancy (`min_size` is satisfied with two of three OSDs). If the NVMe does not boot or
anything goes wrong:

1. Reinstall the **original SD card**, boot from it (NVMe out, or the firmware will prefer
   the SD slot order configured on the Pi — remove the NVMe to be certain).
2. The node boots as it did before; rejoin it with a fresh
   `config/kubeadm-join.storage.yaml` if it dropped out of the cluster.
3. Rook still expects `nvme0n1`; if you already merged the `nvme0n1p3` change, revert that
   entry (Flux will apply it) and the old OSD path is valid again. If you already ran
   `ceph osd rm` in step 7, the old OSD id is gone from the cluster and the old NVMe's
   data is abandoned — with two healthy OSDs the cluster remains consistent and fully
   redundant, but re-plan the migration instead of hot-fixing.

## Repeating for the other nodes

Steps 1-7 are identical for `storage-0` and `storage-1`, with one difference in the end
state: after the last node is migrated, all three device entries in
`rook-ceph-cluster-helmrelease.yaml` become `nvme0n1p3`. Migrate in the order
`storage-2` → `storage-1` → `storage-0`, and re-verify `HEALTH_OK` between each node.
