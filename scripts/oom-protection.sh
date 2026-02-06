#!/bin/bash
#
# oom-protection.sh
# Memory watchdog and OOM protection for DGX Spark
#
# Based on patterns from natolambert/dgx-spark-setup
# Adapted for FellowOS base layer
#
# The DGX Spark has 128GB unified CPU/GPU memory. Large models can
# exhaust memory and freeze the system. This script provides:
# - Memory monitoring with configurable thresholds
# - Automatic cache clearing when memory is low
# - Optional process killing for runaway processes
# - Swap management recommendations
#

set -e

# Configuration
WARN_THRESHOLD=80      # Warn at 80% memory usage
CRITICAL_THRESHOLD=90  # Take action at 90% memory usage
CHECK_INTERVAL=10      # Check every 10 seconds
LOG_FILE="/var/log/fellowos-oom-protection.log"
ENABLE_AUTO_KILL=false # Set to true to auto-kill largest process at critical

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

get_memory_usage() {
    # Returns memory usage percentage (0-100)
    free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}'
}

get_available_gb() {
    # Returns available memory in GB
    free -g | awk '/Mem:/ {print $7}'
}

get_top_memory_processes() {
    # List top 5 memory-consuming processes
    ps aux --sort=-%mem | head -6 | tail -5
}

clear_caches() {
    log "INFO" "Clearing system caches..."
    sync
    echo 3 > /proc/sys/vm/drop_caches
    log "INFO" "Caches cleared"
}

kill_largest_process() {
    if [[ "$ENABLE_AUTO_KILL" != "true" ]]; then
        log "WARN" "Auto-kill disabled. Set ENABLE_AUTO_KILL=true to enable."
        return
    fi

    # Find the largest non-essential process
    local pid=$(ps aux --sort=-%mem | awk 'NR==2 {print $2}')
    local pname=$(ps aux --sort=-%mem | awk 'NR==2 {print $11}')

    # Don't kill essential processes
    case "$pname" in
        *systemd*|*sshd*|*bash*|*zsh*|*init*)
            log "WARN" "Largest process is essential ($pname), not killing"
            return
            ;;
    esac

    log "WARN" "Killing process $pid ($pname) to free memory"
    kill -9 "$pid" 2>/dev/null || true
}

show_status() {
    local usage=$(get_memory_usage)
    local available=$(get_available_gb)

    echo ""
    echo "=== DGX Spark Memory Status ==="
    echo ""
    echo "Memory Usage: ${usage}%"
    echo "Available: ${available}GB"
    echo ""
    echo "Thresholds:"
    echo "  Warning:  ${WARN_THRESHOLD}%"
    echo "  Critical: ${CRITICAL_THRESHOLD}%"
    echo ""
    echo "Top Memory Processes:"
    get_top_memory_processes
    echo ""
}

check_swap() {
    local swap_total=$(free -m | awk '/Swap:/ {print $2}')

    if [[ "$swap_total" -gt 0 ]]; then
        log "WARN" "Swap is enabled (${swap_total}MB). For AI workloads, swap can cause severe slowdowns."
        echo ""
        echo -e "${YELLOW}[WARN]${NC} Swap is enabled. Consider disabling for AI workloads:"
        echo "  sudo swapoff -a"
        echo ""
    fi
}

monitor_loop() {
    log "INFO" "Starting OOM protection monitor (interval: ${CHECK_INTERVAL}s)"
    log "INFO" "Thresholds - Warning: ${WARN_THRESHOLD}%, Critical: ${CRITICAL_THRESHOLD}%"

    while true; do
        local usage=$(get_memory_usage)
        local available=$(get_available_gb)

        if [[ "$usage" -ge "$CRITICAL_THRESHOLD" ]]; then
            log "CRITICAL" "Memory usage at ${usage}% (${available}GB available)"
            clear_caches

            # Re-check after cache clear
            usage=$(get_memory_usage)
            if [[ "$usage" -ge "$CRITICAL_THRESHOLD" ]]; then
                log "CRITICAL" "Still at ${usage}% after cache clear"
                kill_largest_process
            fi

        elif [[ "$usage" -ge "$WARN_THRESHOLD" ]]; then
            log "WARN" "Memory usage at ${usage}% (${available}GB available)"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

setup_systemd_service() {
    cat > /etc/systemd/system/fellowos-oom-protection.service << 'EOF'
[Unit]
Description=FellowOS OOM Protection Monitor
After=network.target

[Service]
Type=simple
ExecStart=/opt/fellowos/scripts/oom-protection.sh --monitor
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable fellowos-oom-protection
    systemctl start fellowos-oom-protection

    log "INFO" "Systemd service installed and started"
}

usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status     Show current memory status"
    echo "  monitor    Start monitoring loop (foreground)"
    echo "  clear      Clear system caches now"
    echo "  install    Install as systemd service"
    echo "  help       Show this help"
    echo ""
    echo "Options (set as environment variables):"
    echo "  WARN_THRESHOLD=80       Warning threshold percentage"
    echo "  CRITICAL_THRESHOLD=90   Critical threshold percentage"
    echo "  CHECK_INTERVAL=10       Check interval in seconds"
    echo "  ENABLE_AUTO_KILL=false  Auto-kill largest process at critical"
    echo ""
}

# Main
case "${1:-status}" in
    status)
        show_status
        check_swap
        ;;
    monitor|--monitor)
        check_swap
        monitor_loop
        ;;
    clear)
        if [[ $EUID -ne 0 ]]; then
            echo "Cache clearing requires root. Use: sudo $0 clear"
            exit 1
        fi
        clear_caches
        show_status
        ;;
    install)
        if [[ $EUID -ne 0 ]]; then
            echo "Service installation requires root. Use: sudo $0 install"
            exit 1
        fi
        setup_systemd_service
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
