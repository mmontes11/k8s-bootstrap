# Raspberry Pi 5 storage node: SD card to NVMe migration

Migrates a Raspberry Pi 5 worker/storage node from an SD-card root filesystem to the 2TB
onboard NVMe module, so the OS lives on fast, durable storage while keeping a dedicated raw
partition for the [rook-ceph](https://rook.io/) OSD. After the first node is migrated, its
disk is captured as a compressed, byte-for-byte golden image pushed to a NAS over NFS, and
piped (decompressed) onto the remaining nodes.

No second Linux machine or USB NVMe enclosure is needed: a freshly flashed microSD card
boots every node as the staging OS, and the NVMe image/partition work is done from there —
the same flow as the
[reference tutorial](https://wolfpaulus.com/rp5-ubuntu-cli/).

## Target layout (2TB NVMe module)

3 partitions. The RPi5 firmware requires a FAT32 `/boot/firmware` partition on the boot
device, hence one more partition than a plain Linux install:

| Partition  | Filesystem             | Size                        | Mount                |
|------------|------------------------|-----------------------------|----------------------|
| `nvme0n1p1` | fat32                 | 512MiB                      | `/boot/firmware`     |
| `nvme0n1p2` | ext4                  | ends at `128GiB` (fs `124G`) | `/`                  |
| `nvme0n1p3` | (raw, unformatted)    | remainder (~1.7TiB)         | none — claimed by rook-ceph |

Rook consumes `nvme0n1p3`. The OS never sees `nvme0n1p3`; rook takes exclusive control of
it, exactly as it does today with the whole-disk `nvme0n1` configuration on the other nodes.

The split is controlled by one number, `OS_END` (`128GiB` below). If you want a different
OS/OSD split, change it consistently in Steps 5 and 6 — nowhere else.

## Safety rules (read first)

1. **One node at a time.** Never migrate two storage nodes in parallel: the cluster must
   never be short two OSDs at once.
2. **One down OSD is tolerated, a *stacked* degradation is not.** With three OSDs and
   `size(ceph_osd_pool) = 3`, a node being offline leaves two working OSDs: `min_size` is
   satisfied, I/O continues, and Ceph shows `HEALTH_WARN` with degraded PGs for the offline
   window. That is expected and acceptable. What is **not** acceptable is starting the
   migration while the cluster is *already* degraded or converging (missing OSD, or
   `active+undersized+...+backfilling` PGs from a previous event) — that stacks a second
   degradation and can leave the cluster unrecoverable. Check on the control plane:

   ```bash
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s
   ```

3. **Keep the original SD card until the node is fully back in service** (see
   [Rollback](#rollback)). It is your safety net.
4. **Merge the rook device-config PR before the migrated node rejoins the cluster** (see
   [Step 10](#step-10-rook-osd-migration)). Otherwise rook still expects the old whole-disk
   `nvme0n1` and will never see `nvme0n1p3`.
5. **The golden image is only valid while `nvme0n1p3` is raw** — captured *before* the node
   first boots (Step 7), so no OSD metadata exists on it yet. Never re-capture the disk
   after the node has rejoined and rook has created the new OSD.

## Tools and hardware

- The node's own hardware: a **fresh ≥16GB microSD card** (the "staging OS" medium, reused
  per node) and the node's **original SD card** (kept untouched for rollback).
- The **NAS** hosting the golden image: `10.0.0.50:/volume1/images`, an NFS export that is
  readable and writable from any IP in `10.0.0.0/24`, mounted at `/mnt/nas` on the staging
  OS. The disk is piped compressed (`zstd`) to it over the network at capture time, and the
  compressed stream is piped back on restore — nothing but pipeline buffers touches local
  disk, so the machines never need 2TB of free space.
- The Ubuntu 24.04 preinstalled server image for Raspberry Pi
  (`ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz` from the
  [Ubuntu releases](https://cdimage.ubuntu.com/releases/24.04/release/) archive, or via
  rpi-imager's built-in catalog).
- rpi-imager on whatever machine you already use to image SD cards.
- Once the staging OS is booted on the Pi: `sudo apt update && sudo apt install -y
  rpi-imager parted gdisk zstd nfs-common` (`e2fsprogs` ships with the base image).

## Migrating the first node (storage-2) — produces the golden image

### Step 1 — Pre-flight on the control plane

```bash
kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s
kubectl get nodes -l node.mmontes.io/type=storage
kubectl -n storage get pods -l app=rook-ceph-osd -o wide    # note which osd pod runs on the target node
```

Per safety rule 2: the cluster must be converged (no missing OSDs, no in-flight
backfills). Note the OSD id of the target node (e.g. `osd-3` on `storage-2`) — you need it
in [Step 10](#step-10-rook-osd-migration).

### Step 2 — Take the node out of the cluster

On the control plane:

```bash
kubectl drain storage-2 --ignore-daemonsets --delete-emptydir-data
```

Then power the Pi off. Its OSD is now down; the cluster runs on the remaining two OSDs
(expected — see safety rule 2).

### Step 3 — Boot the staging OS from a fresh SD card

Image the fresh SD card with rpi-imager as you would any node (customize hostname — e.g.
`rpi5-stage` — a reachable IP and your SSH key). Insert it into the powered-off Pi, power
on, and SSH in.

```bash
sudo apt update && sudo apt install -y rpi-imager parted gdisk zstd nfs-common
lsblk -f      # the NVMe must be visible; it still holds the old OSD's data
```

The staging OS lives on `mmcblk0`; the NVMe (`/dev/nvme0n1`) is unused and unmounted by it,
so everything done to it in the next steps is safe.

### Step 4 — Write the OS image onto the NVMe

On the staging OS (the same image that was written to the SD card):

```bash
wget https://cdimage.ubuntu.com/releases/24.04.4/release/ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz
sudo rpi-imager --cli ubuntu-24.04.4-preinstalled-server-arm64+raspi.img.xz /dev/nvme0n1
```

Double-check the target device with `lsblk` before running rpi-imager — it writes the
second argument, and this step **wipes the old OSD data on `nvme0n1`**. That is intended
(the OSD was drained with the node; it is formally removed in Step 10).

The result is a two-partition GPT: `p1` FAT32 (boot), `p2` ext4 (root, sized for the image,
i.e. a few GiB — not the full disk).

### Step 5 — Partition surgery (NVMe still offline)

Fit `p2` to end at `128GiB`, set its ext4 to `124G`, then create the raw rook partition
`p3` from what is left:

```bash
DEV=/dev/nvme0n1

sudo parted -s $DEV print                        # sanity check: GPT, p1 fat, p2 ext4 (small)
sudo parted -s $DEV resizepart 2 128GiB          # grow p2's end boundary to 128GiB from the start of the disk
sudo e2fsck -f ${DEV}p2                          # check before/during resize
sudo resize2fs ${DEV}p2 124G                     # grow the fs to 124G inside the 128GiB partition

# Create the rook partition from the remainder of the disk. Do NOT format it:
sudo parted -s $DEV mkpart rook 128GiB 100%
sudo sgdisk -t 3:8300 $DEV                       # explicit "Linux filesystem" partition type

# Verify:
sudo parted -s $DEV print
sudo blkid ${DEV}p2 ${DEV}p3                     # p2 must show ext4; p3 must show NOTHING
```

`blkid` printing nothing for `p3` is required: rook provisions an unformatted device
itself. (If for some reason `p2` is *larger* than `128GiB` instead of smaller, shrink first
in the order `e2fsck -f -y` → `resize2fs 124G` → `resizepart`; the commands above only
grow.)

### Step 6 — Per-node configuration into the NVMe boot partition

The freshly written image has no hostname/user/networking customization. Copy the
customized `user-data`/`network-config` files from the staging SD's boot partition onto
the NVMe's `p1` (the tutorial does the same), then edit them for this node:

```bash
sudo mkdir /mnt/nvfat
sudo mount /dev/nvme0n1p1 /mnt/nvfat
sudo cp /boot/firmware/user-data /boot/firmware/network-config /mnt/nvfat/
```

**Do not copy `cmdline.txt`.** rpi-imager stamps every write with a fresh, randomized
disk signature, and the NVMe's own `cmdline.txt` (written in Step 4) already has the
`root=PARTUUID=...` matching *its own* `p2`. The staging SD's `cmdline.txt` encodes the
SD's PARTUUID instead — copying it over would point the NVMe's root= at a partition that
no longer exists once the SD is removed, and the node would fail to boot. Leave the
NVMe's `cmdline.txt` as rpi-imager wrote it; Step 8 appends the required boot parameters
to it in place.

Edit the copies on the mounted `p1`:

- `user-data`: `hostname:` must be the **node name** (`storage-2`) — the node will be
  re-joined under that name.
- `network-config` / netplan section: the node's address, exactly as it was before.

```bash
sudo umount /mnt/nvfat
```

### Step 7 — Capture the golden image (before first boot, `p3` still raw)

Push the fully partitioned, not-yet-booted disk to the NAS over NFS as a pure pipe (the disk
is mostly zeros — the raw `p3` and the unused portion of `p2` dominate, so the compression
ratio is very high; at no point is a 2TB file written to local disk):

```bash
sudo mkdir -p /mnt/nas
sudo mount -t nfs 10.0.0.50:/volume1/images /mnt/nas

# NVMe read → compress (all cores) → push over NFS
sudo dd if=/dev/nvme0n1 bs=4M | sudo zstd -T0 -o /mnt/nas/rpi5-nvme-golden.img.zst
sudo sha256sum /mnt/nas/rpi5-nvme-golden.img.zst | sudo tee /mnt/nas/rpi5-nvme-golden.img.zst.sha256
sync
```

The full-disk read is the dominant cost (a couple of minutes at NVMe speed); what traverses
the network is the compressed file, roughly a few hundred MB. The `.sha256` side file is
what every restore verifies against before overwriting an NVMe.

### Step 8 — First NVMe boot

Shut down the staging OS, **remove the SD card**, power on. The firmware tries the SD slot
first, finds nothing, and boots the NVMe.

SSH in and verify the layout is intact (first-boot auto-grow only extends the filesystem
*within* `p2`'s end boundary, so `p3` is safe, but confirm):

```bash
lsblk /dev/nvme0n1
df -h /                    # / ≈ 124G, on nvme0n1p2
blkid /dev/nvme0n1p3       # must print nothing
hostnamectl                 # must be storage-2
```

If anything looks wrong, stop and roll back (SD card). Otherwise run the standard node
preparation (works unchanged — `cmdline.txt` now lives on the NVMe `p1`):

```bash
sudo bash node-prepare.sh
sudo reboot
```

### Step 9 — Join the cluster again

On the control plane, generate a fresh join config (see `Makefile`):

```bash
./scripts/join-config.sh   # writes config/kubeadm-join.storage.yaml (fresh token + ca-hash)
```

Copy it to the node and join:

```bash
sudo bash node.sh 'config/kubeadm-join.storage.yaml'
```

Verify on the control plane that the node is back as `Ready` with the storage label/taint:

```bash
kubectl get nodes -l node.mmontes.io/type=storage
```

### Step 10 — Rook OSD migration

Precondition: the companion PR in `mmontes11/k8s-infrastructure`, which switches
`storage-2`'s device entry from `nvme0n1` to `nvme0n1p3` in
`infrastructure/rook/rook-ceph-cluster/rook-ceph-cluster-helmrelease.yaml`, **is merged and
applied by Flux** before this step.

1. Remove the old OSD from the cluster (its data was wiped in Step 4). Substitute `3`
   below with the OSD id you noted for this node in Step 1 (`osd-3` on `storage-2` at
   the time of writing — it will differ for `storage-1`/`storage-0`):

   ```bash
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph osd out 3
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph osd rm 3
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s
   ```

2. Rook discovers the raw `nvme0n1p3` and creates a new OSD on it. Watch it come up:

   ```bash
   kubectl -n storage get pods -l app=rook-ceph-osd -o wide
   kubectl -n storage get osds
   kubectl -n storage exec deploy/rook-ceph-tools -- ceph -s   # backfilling will show, converging
   ```

3. Wait for convergence (all PGs `active+clean`) before migrating the next node.

## Migrating the remaining nodes from the golden image

`storage-1` and `storage-0` skip Steps 4–7: the golden image already contains the OS, the
`128GiB`/`~1.7TiB` partition layout, and an empty raw `p3`. For each node:

1. **Pre-flight**: per safety rule 2, the cluster must be converged with no missing OSDs.
2. **Take the node out**: `kubectl drain <node> ...`, power off, keep its original SD card.
3. **Stage**: fresh (or re-imaged) SD card per Step 3. No USB stick is needed — the image
   comes over the network: the NFS export is writable/readable from any IP in `10.0.0.0/24`.
4. **Pull, verify and restore the image onto the NVMe** (no rpi-imager, no partition
   surgery; the compressed stream is pulled over NFS and decompressed in the pipeline
   straight onto the NVMe — nothing lands on local disk as a 2TB image):

   ```bash
   sudo mkdir -p /mnt/nas
   sudo mount -t nfs 10.0.0.50:/volume1/images /mnt/nas
   sudo sha256sum -c /mnt/nas/rpi5-nvme-golden.img.zst.sha256

   # NFS read → decompress (all cores) → NVMe write
   sudo zstd -dc /mnt/nas/rpi5-nvme-golden.img.zst | sudo dd of=/dev/nvme0n1 bs=4M status=progress
   sync
   ```

5. **Per-node configuration**: the golden's `p1` still carries `storage-2`'s hostname and
   address. Mount `p1` (FAT32) and edit `user-data` (hostname → the node name) and the
   network config (→ the node's address) before its first boot. The filesystem on `p2` has
   not consumed cloud-init yet, so the edited `user-data` applies on first boot:

   ```bash
   sudo mkdir /mnt/nvfat
   sudo mount /dev/nvme0n1p1 /mnt/nvfat
   # edit /mnt/nvfat/user-data and /mnt/nvfat/network-config
   sudo umount /mnt/nvfat
   ```

6. **First NVMe boot**: remove the SD, power on, verify layout and hostname (Step 8 checks),
   `sudo bash node-prepare.sh`, `sudo reboot`.
7. **Rejoin** (Steps 9) with a fresh join config.
8. **Rook** (Step 10): first make sure this node's own device entry in
   `rook-ceph-cluster-helmrelease.yaml` is already `nvme0n1p3` (same one-line change, merged
   and reconciled by Flux), then remove the old OSD id and let rook provision the new one
   on `p3`. Wait for convergence before the next node.

After the last node, all three device entries in the helmrelease are `nvme0n1p3`.

## Rook re-provisioning cleanup

If a newly created OSD ends up in a bad state and you want to start it over, wipe the rook
partition and let rook re-provision it:

```bash
sudo bash scripts/cleanup-nvme.sh          # default target: /dev/nvme0n1p3
```

The script performs no checks — it zeroes the start of the target partition, discards it,
re-probes, and removes `/var/lib/rook`. Pass a different device explicitly if the layout
differs (e.g. the legacy whole-disk `nvme0n1` on a node that has not been migrated yet).
You own the target argument.

## Rollback

Before the node rejoins the cluster, all data lives on the two remaining OSDs at full
redundancy (`min_size` is satisfied with two of three OSDs). If the NVMe does not boot or
anything goes wrong:

1. Reinstall the **original SD card**, boot from it (remove the NVMe to be certain the
   firmware does not try it first).
2. The node boots as it did before; rejoin it with a fresh
   `config/kubeadm-join.storage.yaml` if it dropped out of the cluster.
3. Rook still expects `nvme0n1`; if you already merged the `nvme0n1p3` change, revert that
   entry (Flux will apply it) and the old whole-disk device is valid again — then wipe it
   first with `scripts/cleanup-nvme.sh /dev/nvme0n1`, because the image/partition surgery
   destroyed the old OSD data. If you already ran `ceph osd rm`, the old OSD id is gone
   from the cluster: with two healthy OSDs the data is safe, but re-plan the migration
   instead of hot-fixing.
