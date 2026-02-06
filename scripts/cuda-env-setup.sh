#!/bin/bash
#
# cuda-env-setup.sh
# Auto-discover and configure CUDA environment for DGX Spark
#
# Based on patterns from GuigsEvt/dgx_spark_config
# Adapted for FellowOS base layer
#
# This script:
# - Auto-detects CUDA, cuDNN, NCCL, cuSPARSELt installations
# - Exports correct environment variables
# - Configures PyTorch/Triton for Blackwell (SM 12.x) architecture
# - Can be sourced or run to generate exports
#

# DGX Spark specifics
SPARK_GPU_ARCH="12.1"           # Blackwell GB10
SPARK_CUDA_ARCH_LIST="12.1a"    # For PyTorch compilation

# Colors (only if interactive)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Find CUDA installation
find_cuda() {
    local cuda_paths=(
        "/usr/local/cuda"
        "/usr/local/cuda-13.0"
        "/usr/local/cuda-13"
        "/opt/cuda"
    )

    for path in "${cuda_paths[@]}"; do
        if [[ -d "$path" && -f "$path/bin/nvcc" ]]; then
            echo "$path"
            return 0
        fi
    done

    # Try nvidia-smi to find CUDA version
    if command -v nvidia-smi &>/dev/null; then
        local cuda_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
        log_warn "CUDA not found in standard paths, driver version: $cuda_ver"
    fi

    return 1
}

# Find cuDNN
find_cudnn() {
    local cudnn_paths=(
        "/usr/lib/aarch64-linux-gnu"
        "/usr/local/cuda/lib64"
        "/opt/cudnn/lib"
    )

    for path in "${cudnn_paths[@]}"; do
        if [[ -f "$path/libcudnn.so" ]] || ls "$path"/libcudnn.so.* &>/dev/null 2>&1; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Find NCCL
find_nccl() {
    local nccl_paths=(
        "/usr/lib/aarch64-linux-gnu"
        "/usr/local/nccl/lib"
        "/opt/nccl/lib"
    )

    for path in "${nccl_paths[@]}"; do
        if [[ -f "$path/libnccl.so" ]] || ls "$path"/libnccl.so.* &>/dev/null 2>&1; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Find cuSPARSELt
find_cusparselt() {
    local paths=(
        "/usr/local/cuda/lib64"
        "/usr/lib/aarch64-linux-gnu"
        "/opt/cusparselt/lib"
    )

    for path in "${paths[@]}"; do
        if [[ -f "$path/libcusparseLt.so" ]] || ls "$path"/libcusparseLt.so.* &>/dev/null 2>&1; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Find ptxas for Triton
find_ptxas() {
    local cuda_home="${1:-/usr/local/cuda}"

    if [[ -f "$cuda_home/bin/ptxas" ]]; then
        echo "$cuda_home/bin/ptxas"
        return 0
    fi

    # Search in PATH
    if command -v ptxas &>/dev/null; then
        command -v ptxas
        return 0
    fi

    return 1
}

# Get CUDA version
get_cuda_version() {
    local cuda_home="$1"
    if [[ -f "$cuda_home/version.json" ]]; then
        grep -o '"cuda" *: *"[^"]*"' "$cuda_home/version.json" | cut -d'"' -f4
    elif [[ -f "$cuda_home/version.txt" ]]; then
        cat "$cuda_home/version.txt" | grep -oP 'CUDA Version \K[0-9.]+'
    elif [[ -f "$cuda_home/bin/nvcc" ]]; then
        "$cuda_home/bin/nvcc" --version | grep -oP 'release \K[0-9.]+'
    else
        echo "unknown"
    fi
}

# Generate environment exports
generate_exports() {
    local cuda_home=$(find_cuda)
    local cudnn_path=$(find_cudnn)
    local nccl_path=$(find_nccl)
    local cusparselt_path=$(find_cusparselt)

    if [[ -z "$cuda_home" ]]; then
        log_error "CUDA not found!"
        return 1
    fi

    local cuda_version=$(get_cuda_version "$cuda_home")
    local ptxas_path=$(find_ptxas "$cuda_home")

    log_info "Detected CUDA $cuda_version at $cuda_home"

    # Output exports
    echo "# FellowOS CUDA Environment - Auto-generated"
    echo "# CUDA $cuda_version for DGX Spark (Blackwell GB10)"
    echo ""
    echo "# CUDA paths"
    echo "export CUDA_HOME=\"$cuda_home\""
    echo "export CUDA_PATH=\"$cuda_home\""
    echo "export PATH=\"$cuda_home/bin:\$PATH\""
    echo "export LD_LIBRARY_PATH=\"$cuda_home/lib64:\$LD_LIBRARY_PATH\""

    if [[ -n "$cudnn_path" ]]; then
        log_info "Detected cuDNN at $cudnn_path"
        echo ""
        echo "# cuDNN"
        echo "export CUDNN_PATH=\"$cudnn_path\""
        echo "export LD_LIBRARY_PATH=\"$cudnn_path:\$LD_LIBRARY_PATH\""
    else
        log_warn "cuDNN not found"
    fi

    if [[ -n "$nccl_path" ]]; then
        log_info "Detected NCCL at $nccl_path"
        echo ""
        echo "# NCCL"
        echo "export NCCL_ROOT=\"${nccl_path%/lib}\""
        echo "export LD_LIBRARY_PATH=\"$nccl_path:\$LD_LIBRARY_PATH\""
    else
        log_warn "NCCL not found"
    fi

    if [[ -n "$cusparselt_path" ]]; then
        log_info "Detected cuSPARSELt at $cusparselt_path"
        echo ""
        echo "# cuSPARSELt"
        echo "export LD_LIBRARY_PATH=\"$cusparselt_path:\$LD_LIBRARY_PATH\""
    fi

    echo ""
    echo "# DGX Spark / Blackwell GPU architecture"
    echo "export TORCH_CUDA_ARCH_LIST=\"$SPARK_CUDA_ARCH_LIST\""
    echo "export CUDA_VISIBLE_DEVICES=0"

    if [[ -n "$ptxas_path" ]]; then
        log_info "Detected ptxas at $ptxas_path"
        echo ""
        echo "# Triton compiler"
        echo "export TRITON_PTXAS_PATH=\"$ptxas_path\""
    fi

    echo ""
    echo "# PyTorch settings for DGX Spark"
    echo "export PYTORCH_CUDA_ALLOC_CONF=\"expandable_segments:True\""
    echo ""
    echo "# Disable memory-hungry features during development"
    echo "# export PYTORCH_NO_CUDA_MEMORY_CACHING=1"
}

# Create profile.d script
install_profile() {
    local output_file="${1:-/etc/profile.d/fellowos-cuda.sh}"

    if [[ $EUID -ne 0 ]]; then
        echo "Installation requires root. Use: sudo $0 install"
        exit 1
    fi

    log_info "Installing CUDA environment to $output_file"
    generate_exports > "$output_file"
    chmod +x "$output_file"
    log_info "Done. Log out and back in, or run: source $output_file"
}

# Show detected configuration
show_status() {
    echo ""
    echo "=== DGX Spark CUDA Environment Detection ==="
    echo ""

    local cuda_home=$(find_cuda)
    if [[ -n "$cuda_home" ]]; then
        local cuda_version=$(get_cuda_version "$cuda_home")
        echo "CUDA:       $cuda_version ($cuda_home)"
    else
        echo "CUDA:       NOT FOUND"
    fi

    local cudnn_path=$(find_cudnn)
    if [[ -n "$cudnn_path" ]]; then
        echo "cuDNN:      $cudnn_path"
    else
        echo "cuDNN:      NOT FOUND"
    fi

    local nccl_path=$(find_nccl)
    if [[ -n "$nccl_path" ]]; then
        echo "NCCL:       $nccl_path"
    else
        echo "NCCL:       NOT FOUND"
    fi

    local cusparselt_path=$(find_cusparselt)
    if [[ -n "$cusparselt_path" ]]; then
        echo "cuSPARSELt: $cusparselt_path"
    else
        echo "cuSPARSELt: NOT FOUND"
    fi

    local ptxas_path=$(find_ptxas "$cuda_home")
    if [[ -n "$ptxas_path" ]]; then
        echo "ptxas:      $ptxas_path"
    else
        echo "ptxas:      NOT FOUND"
    fi

    echo ""
    echo "GPU Architecture: Blackwell GB10 (SM $SPARK_GPU_ARCH)"
    echo ""

    # Show nvidia-smi if available
    if command -v nvidia-smi &>/dev/null; then
        echo "GPU Status:"
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
    fi
    echo ""
}

usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status    Show detected CUDA environment"
    echo "  export    Generate export statements (pipe to eval or file)"
    echo "  install   Install to /etc/profile.d/fellowos-cuda.sh (requires root)"
    echo "  help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Show what's detected"
    echo "  $0 export                    # Print exports to stdout"
    echo "  $0 export > cuda-env.sh      # Save to file"
    echo "  eval \"\$($0 export)\"          # Apply to current shell"
    echo "  sudo $0 install              # Install system-wide"
    echo ""
}

# Main
case "${1:-status}" in
    status)
        show_status
        ;;
    export)
        generate_exports
        ;;
    install)
        install_profile "${2:-/etc/profile.d/fellowos-cuda.sh}"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac
