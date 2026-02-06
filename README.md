# DGX Spark FellowOS Image

Base layer setup for FellowOS on NVIDIA DGX Spark.

## Overview

This project defines the disk partitioning, ZFS layout, and DGX OS installation that serves as the foundation layer for FellowOS on DGX Spark hardware.

## Target Hardware

- NVIDIA DGX Spark
- 2TB SSD (1.5TB AI storage) or 4TB SSD (3.5TB AI storage)

## Software Stack

- **Base OS:** DGX OS 7.4.0 (Ubuntu 24.04, ARM64)
- **GPU Driver:** 580.126.09
- **CUDA:** 13.0 Update 2
- **Filesystem:** ZFS

## Partition Layout

| Partition | Size | Type | Purpose |
|-----------|------|------|---------|
| nvme0n1p1 | 512MB | FAT32 | EFI System Partition |
| nvme0n1p2 | remainder | ZFS | rpool |

## ZFS Dataset Layout

```
rpool
├── ROOT/
│   └── dgxos              mountpoint=/         quota=500G
├── ai/
│   ├── models             mountpoint=/ai/models
│   └── data               mountpoint=/ai/data
└── home                   mountpoint=/home
```

## Quick Start

1. Boot DGX Spark from installation media
2. Run `scripts/partition-and-zfs.sh` to set up disk layout
3. Install DGX OS 7.4.0 (see `docs/dgx-stack-install.md`)
4. Run `scripts/post-install-setup.sh` for final configuration
5. Run `scripts/cuda-env-setup.sh install` to configure CUDA paths

## Scripts

| Script | Purpose |
|--------|---------|
| `partition-and-zfs.sh` | Partition disk and create ZFS pool/datasets |
| `post-install-setup.sh` | Post-DGX-OS verification and directory setup |
| `cuda-env-setup.sh` | Auto-detect and configure CUDA/cuDNN/NCCL environment |
| `oom-protection.sh` | Memory watchdog to prevent OOM freezes (128GB unified memory) |
| `service-template.sh` | Template for creating AI service management scripts |

### OOM Protection

The DGX Spark's 128GB unified CPU/GPU memory can be exhausted by large models. The OOM protection script monitors memory and takes action:

```bash
# Check memory status
./scripts/oom-protection.sh status

# Run as background monitor
sudo ./scripts/oom-protection.sh monitor

# Install as systemd service
sudo ./scripts/oom-protection.sh install
```

### CUDA Environment

Auto-detect and configure CUDA paths for the Blackwell GB10 GPU:

```bash
# Show detected configuration
./scripts/cuda-env-setup.sh status

# Apply to current shell
eval "$(./scripts/cuda-env-setup.sh export)"

# Install system-wide
sudo ./scripts/cuda-env-setup.sh install
```

### Service Template

Create consistent service management scripts for AI services:

```bash
# Copy template for a new service
cp scripts/service-template.sh scripts/vllm.sh

# Edit configuration section, then use:
./scripts/vllm.sh serve    # Start
./scripts/vllm.sh stop     # Stop
./scripts/vllm.sh status   # Check status
./scripts/vllm.sh logs     # View logs
```

## Documentation

- [ZFS Layout](docs/zfs-layout.md) - Detailed ZFS pool and dataset configuration
- [DGX Stack Install](docs/dgx-stack-install.md) - DGX OS 7.4.0 installation steps

## Related

- [FellowOS](https://github.com/walkyri/FellowOS) - AI operating system built on this base layer
