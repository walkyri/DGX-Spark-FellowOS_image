#!/bin/bash
#
# post-install-setup.sh
# Post-installation configuration for DGX Spark FellowOS base layer
#
# Run after DGX OS installation to configure ZFS, verify stack, and prepare for FellowOS
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${GREEN}=== $1 ===${NC}"
    echo ""
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_section "DGX Spark FellowOS Post-Install Setup"

# 1. Verify ZFS
log_section "Verifying ZFS Configuration"

if ! command -v zfs &>/dev/null; then
    log_error "ZFS not found. Installing..."
    apt update && apt install -y zfsutils-linux
fi

log_info "Pool status:"
zpool status rpool || log_error "rpool not found!"

log_info "Dataset list:"
zfs list -r rpool

# 2. Verify NVIDIA stack
log_section "Verifying NVIDIA Stack"

log_info "GPU Driver:"
if nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv
else
    log_error "nvidia-smi failed - GPU driver may not be installed correctly"
fi

log_info "CUDA version:"
if command -v nvcc &>/dev/null; then
    nvcc --version | grep "release"
else
    log_warn "nvcc not in PATH - CUDA toolkit may need PATH configuration"
fi

log_info "Docker:"
docker --version || log_error "Docker not installed"

log_info "NVIDIA Container Toolkit:"
if docker info 2>/dev/null | grep -q "nvidia"; then
    log_info "NVIDIA runtime available in Docker"
else
    log_warn "NVIDIA Docker runtime may not be configured"
fi

# 3. Test GPU in container
log_section "Testing GPU Access in Container"

log_info "Running nvidia-smi in container..."
if docker run --rm --gpus all nvidia/cuda:13.0-base-ubuntu24.04 nvidia-smi; then
    log_info "GPU access in containers: OK"
else
    log_error "GPU access in containers: FAILED"
fi

# 4. Set up directories
log_section "Setting Up Directory Structure"

# Create standard directories in /ai
mkdir -p /ai/models/hub
mkdir -p /ai/models/ollama
mkdir -p /ai/models/custom
mkdir -p /ai/data/datasets
mkdir -p /ai/data/training
mkdir -p /ai/cache

# Set permissions (assuming main user is dgxuser or similar)
MAIN_USER=$(getent passwd 1000 | cut -d: -f1)
if [[ -n "$MAIN_USER" ]]; then
    log_info "Setting ownership to $MAIN_USER for /ai directories"
    chown -R "$MAIN_USER:$MAIN_USER" /ai/models /ai/data /ai/cache
else
    log_warn "Could not determine main user (UID 1000)"
fi

log_info "Directory structure:"
tree -L 2 /ai 2>/dev/null || ls -la /ai/

# 5. Configure environment
log_section "Configuring Environment"

# Create /etc/profile.d script for AI paths
cat > /etc/profile.d/fellowos-ai.sh << 'EOF'
# FellowOS AI environment configuration

# Model cache directories
export HF_HOME=/ai/cache/huggingface
export TRANSFORMERS_CACHE=/ai/cache/huggingface/hub
export OLLAMA_MODELS=/ai/models/ollama

# CUDA paths (if not already set)
if [[ -d /usr/local/cuda ]]; then
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
fi
EOF

chmod +x /etc/profile.d/fellowos-ai.sh
log_info "Created /etc/profile.d/fellowos-ai.sh"

# 6. ZFS snapshot of clean state
log_section "Creating Baseline Snapshot"

SNAPSHOT_DATE=$(date +%Y%m%d)
zfs snapshot -r "rpool@baseline-${SNAPSHOT_DATE}"
log_info "Created recursive snapshot: rpool@baseline-${SNAPSHOT_DATE}"

log_info "Snapshots:"
zfs list -t snapshot

# 7. Summary
log_section "Setup Complete"

echo "DGX Spark FellowOS base layer is ready."
echo ""
echo "System information:"
echo "  - Hostname: $(hostname)"
echo "  - Kernel: $(uname -r)"
echo "  - GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'Unknown')"
echo "  - ZFS Pool: rpool"
echo "  - AI Storage: /ai/models, /ai/data"
echo ""
echo "Next steps:"
echo "  1. Reboot to verify clean boot"
echo "  2. Install FellowOS layer"
echo ""
