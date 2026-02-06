# DGX OS 7.4.0 Installation on DGX Spark

## Prerequisites

- NVIDIA DGX Spark hardware
- DGX OS 7.4.0 installation media (USB)
- Disk already partitioned with ZFS layout (see `partition-and-zfs.sh`)

## Download DGX OS

DGX OS is available from NVIDIA's enterprise software portal:

1. Log in to [NVIDIA Enterprise Software](https://enterprise.nvidia.com/)
2. Navigate to DGX Software Downloads
3. Download DGX OS 7.4.0 ISO for ARM64 (DGX Spark)
4. Create bootable USB with the ISO

## Installation Steps

### 1. Boot from Installation Media

1. Insert USB into DGX Spark
2. Power on and enter boot menu (typically F12 or hold power button)
3. Select USB boot device

### 2. Installation Type

When prompted, select **Custom Installation** to use our pre-configured ZFS layout.

> **Note:** DGX OS installer may have its own ZFS support. If it conflicts with our layout, we may need to:
> - Use the installer's ZFS option and configure datasets post-install
> - Or install to a temporary ext4 root and migrate to ZFS

### 3. Partition Selection

Point the installer to use:
- EFI: `/dev/nvme0n1p1` (512MB FAT32)
- Root: ZFS dataset `rpool/ROOT/dgxos`

### 4. Complete Installation

Follow the installer prompts:
- Set hostname (e.g., `dgx-spark-fellow`)
- Create admin user
- Configure network
- Set timezone

### 5. First Boot

After installation completes:
1. Remove USB
2. Reboot
3. Log in as admin user

## Post-Installation

### Verify DGX Stack

```bash
# Check GPU driver
nvidia-smi

# Check CUDA
nvcc --version

# Check Docker
docker --version
docker run --rm --gpus all nvidia/cuda:13.0-base-ubuntu24.04 nvidia-smi
```

### Expected Versions (DGX OS 7.4.0)

| Component | Version |
|-----------|---------|
| GPU Driver | 580.126.09 |
| CUDA Toolkit | 13.0 Update 2 |
| Docker | 29.1.3 |
| NVIDIA Container Toolkit | 1.18.2 |
| Linux Kernel | 6.17.0-1008-nvidia |

### Verify ZFS

```bash
# Pool status
zpool status rpool

# Dataset list
zfs list

# Verify mountpoints
df -h /
df -h /ai/models
df -h /ai/data
df -h /home
```

### Run Post-Install Script

```bash
sudo ~/Projects/DGX-Spark-FellowOS_image/scripts/post-install-setup.sh
```

## Troubleshooting

### ZFS Root Not Booting

If the system fails to boot from ZFS root:

1. Boot from live USB
2. Import pool: `zpool import -R /mnt rpool`
3. Check boot configuration:
   ```bash
   cat /mnt/etc/fstab
   ls -la /mnt/boot/efi
   ```
4. Regenerate initramfs if needed:
   ```bash
   mount --bind /dev /mnt/dev
   mount --bind /proc /mnt/proc
   mount --bind /sys /mnt/sys
   chroot /mnt
   update-initramfs -u -k all
   ```

### GPU Not Detected

```bash
# Check if driver loaded
lsmod | grep nvidia

# Check dmesg for errors
dmesg | grep -i nvidia

# Reinstall driver if needed
sudo apt install --reinstall nvidia-driver-580
```

## References

- [DGX OS 7 User Guide](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/)
- [DGX Spark User Guide](https://docs.nvidia.com/dgx/dgx-spark/)
- [DGX OS 7.4.0 Release Notes](https://docs.nvidia.com/dgx/dgx-os-7-user-guide/release_notes.html)
