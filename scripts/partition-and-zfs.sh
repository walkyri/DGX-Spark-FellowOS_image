#!/bin/bash
#
# partition-and-zfs.sh
# Partition disk and create ZFS pool/datasets for DGX Spark FellowOS
#
# WARNING: This script will DESTROY all data on the target disk!
#

set -e

# Configuration
DISK="${1:-/dev/nvme0n1}"
EFI_SIZE="512M"
POOL_NAME="rpool"
SYSTEM_QUOTA="500G"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if disk exists
if [[ ! -b "$DISK" ]]; then
    log_error "Disk $DISK does not exist"
    exit 1
fi

# Show disk info
log_info "Target disk: $DISK"
lsblk "$DISK"
echo ""

# Get disk size for display
DISK_SIZE=$(lsblk -b -d -n -o SIZE "$DISK")
DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
log_info "Disk size: ${DISK_SIZE_GB}GB"

# Calculate AI storage (total - 512MB EFI - 500GB system)
AI_SIZE_GB=$((DISK_SIZE_GB - 500))
log_info "AI storage will be approximately: ${AI_SIZE_GB}GB"

# Confirmation
echo ""
log_warn "This will DESTROY ALL DATA on $DISK!"
echo ""
read -p "Type 'YES' to continue: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
    log_info "Aborted."
    exit 0
fi

# Unmount any existing mounts
log_info "Unmounting any existing partitions..."
umount "${DISK}"* 2>/dev/null || true

# Destroy existing ZFS pool if present
if zpool list "$POOL_NAME" &>/dev/null; then
    log_info "Destroying existing pool: $POOL_NAME"
    zpool destroy "$POOL_NAME"
fi

# Wipe disk
log_info "Wiping disk signatures..."
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"

# Create GPT partition table
log_info "Creating GPT partition table..."
parted -s "$DISK" mklabel gpt

# Create EFI partition (512MB, FAT32)
log_info "Creating EFI partition (${EFI_SIZE})..."
parted -s "$DISK" mkpart "EFI" fat32 1MiB "${EFI_SIZE}"
parted -s "$DISK" set 1 esp on

# Create ZFS partition (remainder)
log_info "Creating ZFS partition (remainder of disk)..."
parted -s "$DISK" mkpart "zfs" "${EFI_SIZE}" 100%

# Wait for partitions to appear
sleep 2
partprobe "$DISK"
sleep 2

# Determine partition names (handles both nvme and sd naming)
if [[ "$DISK" == *"nvme"* ]]; then
    EFI_PART="${DISK}p1"
    ZFS_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ZFS_PART="${DISK}2"
fi

# Format EFI partition
log_info "Formatting EFI partition as FAT32..."
mkfs.fat -F 32 -n EFI "$EFI_PART"

# Create ZFS pool
log_info "Creating ZFS pool: $POOL_NAME"
zpool create -f \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl \
    -O compression=lz4 \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O canmount=off \
    -O mountpoint=/ \
    -R /mnt \
    "$POOL_NAME" "$ZFS_PART"

# Create datasets
log_info "Creating ZFS datasets..."

# ROOT container
zfs create -o canmount=off -o mountpoint=none "$POOL_NAME/ROOT"

# System root dataset
zfs create \
    -o canmount=noauto \
    -o mountpoint=/ \
    -o quota="$SYSTEM_QUOTA" \
    -o reservation="$SYSTEM_QUOTA" \
    -o atime=off \
    "$POOL_NAME/ROOT/dgxos"

# AI container
zfs create -o canmount=off -o mountpoint=none "$POOL_NAME/ai"

# AI models dataset
zfs create \
    -o mountpoint=/ai/models \
    -o recordsize=1M \
    -o atime=off \
    "$POOL_NAME/ai/models"

# AI data dataset
zfs create \
    -o mountpoint=/ai/data \
    -o recordsize=1M \
    -o atime=off \
    "$POOL_NAME/ai/data"

# Home dataset
zfs create \
    -o mountpoint=/home \
    -o atime=off \
    "$POOL_NAME/home"

# Set boot filesystem
zpool set bootfs="$POOL_NAME/ROOT/dgxos" "$POOL_NAME"

# Mount the root dataset
zfs mount "$POOL_NAME/ROOT/dgxos"

# Create and mount EFI directory
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

# Show results
echo ""
log_info "ZFS pool and datasets created successfully!"
echo ""
echo "Pool status:"
zpool status "$POOL_NAME"
echo ""
echo "Dataset list:"
zfs list -r "$POOL_NAME"
echo ""
echo "Mountpoints:"
df -h /mnt /mnt/boot/efi /mnt/ai/models /mnt/ai/data /mnt/home 2>/dev/null || df -h | grep -E "(mnt|Filesystem)"
echo ""
log_info "Disk is ready for DGX OS installation at /mnt"
log_info "EFI partition mounted at /mnt/boot/efi"
