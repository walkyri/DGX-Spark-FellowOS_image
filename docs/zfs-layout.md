# ZFS Layout for DGX Spark FellowOS

## Design Principles

- Single pool (`rpool`) for simplified management
- Dataset-based separation of system vs AI data
- Quotas enforce the 500GB system / remaining AI split
- Compression enabled for space efficiency
- Snapshots supported for easy rollback

## Pool Configuration

### Pool: rpool

Created on the second partition after EFI:

```
/dev/nvme0n1p2 (remainder of disk after 512MB EFI)
```

Pool-level properties:
- `ashift=12` (4K sectors, standard for NVMe)
- `autotrim=on` (SSD TRIM support)

## Dataset Hierarchy

```
rpool
├── ROOT/
│   └── dgxos              System root
├── ai/
│   ├── models             AI model storage
│   └── data               Training data, datasets
└── home                   User home directories
```

## Dataset Properties

### rpool/ROOT/dgxos (System Root)

| Property | Value | Purpose |
|----------|-------|---------|
| mountpoint | / | Root filesystem |
| quota | 500G | Limit system to 500GB |
| reservation | 500G | Guarantee 500GB available |
| compression | lz4 | Space efficiency |
| atime | off | Performance (no access time updates) |
| xattr | sa | Extended attributes in inodes |
| acltype | posixacl | POSIX ACL support |

### rpool/ai/models (Model Storage)

| Property | Value | Purpose |
|----------|-------|---------|
| mountpoint | /ai/models | Model files location |
| compression | lz4 | Compresses well for checkpoints |
| recordsize | 1M | Large files (model weights) |
| atime | off | Performance |

### rpool/ai/data (Training Data)

| Property | Value | Purpose |
|----------|-------|---------|
| mountpoint | /ai/data | Datasets, training data |
| compression | lz4 | Good for text/structured data |
| recordsize | 1M | Large file optimization |
| atime | off | Performance |

### rpool/home (User Homes)

| Property | Value | Purpose |
|----------|-------|---------|
| mountpoint | /home | User directories |
| compression | lz4 | General compression |
| atime | off | Performance |

## Capacity Planning

### 2TB SSD

| Dataset | Allocated |
|---------|-----------|
| rpool/ROOT/dgxos | 500GB (quota) |
| rpool/ai/* | ~1.5TB |
| rpool/home | shared with ai |

### 4TB SSD

| Dataset | Allocated |
|---------|-----------|
| rpool/ROOT/dgxos | 500GB (quota) |
| rpool/ai/* | ~3.5TB |
| rpool/home | shared with ai |

## Snapshot Strategy

Recommended snapshots:

```bash
# Before major updates
zfs snapshot rpool/ROOT/dgxos@pre-update-$(date +%Y%m%d)

# Before model training runs
zfs snapshot rpool/ai/models@pre-training-$(date +%Y%m%d)

# Automated daily (via cron or systemd timer)
zfs snapshot -r rpool@daily-$(date +%Y%m%d)
```

## Recovery

Boot from previous snapshot if system fails:

1. Boot from live USB
2. Import pool: `zpool import -R /mnt rpool`
3. List snapshots: `zfs list -t snapshot`
4. Rollback: `zfs rollback rpool/ROOT/dgxos@pre-update-YYYYMMDD`
