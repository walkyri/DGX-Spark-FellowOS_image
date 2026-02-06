#!/bin/bash
#
# service-template.sh
# Template for creating FellowOS service management scripts
#
# Based on patterns from eelbaz/dgx-spark-vllm-setup
# Adapted for FellowOS base layer
#
# This template provides a consistent interface for AI services:
# - serve: Start the service
# - stop: Stop the service
# - status: Check service status
# - logs: View service logs
# - restart: Restart the service
#
# To create a new service script:
# 1. Copy this template: cp service-template.sh myservice.sh
# 2. Edit the CONFIGURATION section
# 3. Implement the start_service() function
# 4. chmod +x myservice.sh
#

set -e

# ============================================
# CONFIGURATION - Edit this section
# ============================================

SERVICE_NAME="myservice"
SERVICE_DESCRIPTION="My AI Service"
SERVICE_PORT=8080
SERVICE_HOST="0.0.0.0"

# Paths
SERVICE_DIR="/opt/fellowos/services/${SERVICE_NAME}"
VENV_DIR="${SERVICE_DIR}/venv"
LOG_FILE="/var/log/fellowos/${SERVICE_NAME}.log"
PID_FILE="/var/run/fellowos/${SERVICE_NAME}.pid"

# GPU settings
GPU_MEMORY_FRACTION=0.9
CUDA_VISIBLE_DEVICES=0

# ============================================
# DO NOT EDIT BELOW THIS LINE
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Ensure directories exist
ensure_dirs() {
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    mkdir -p "$SERVICE_DIR"
}

# Check if service is running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Get PID
get_pid() {
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE"
    fi
}

# ============================================
# SERVICE IMPLEMENTATION - Customize this
# ============================================

start_service() {
    # Example: vLLM server
    # Customize this function for your service

    log_info "Starting ${SERVICE_NAME}..."

    # Activate virtual environment if exists
    if [[ -f "${VENV_DIR}/bin/activate" ]]; then
        source "${VENV_DIR}/bin/activate"
    fi

    # Set CUDA environment
    export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES}"

    # Example command - replace with your service
    # python -m vllm.entrypoints.openai.api_server \
    #     --host "${SERVICE_HOST}" \
    #     --port "${SERVICE_PORT}" \
    #     --model "meta-llama/Llama-3.1-8B-Instruct" \
    #     --gpu-memory-utilization "${GPU_MEMORY_FRACTION}" \
    #     >> "$LOG_FILE" 2>&1 &

    # Placeholder - replace with actual service start
    echo "Service ${SERVICE_NAME} would start here" >> "$LOG_FILE"
    echo "Listening on ${SERVICE_HOST}:${SERVICE_PORT}" >> "$LOG_FILE"

    # For demonstration, start a simple background process
    # Replace this with your actual service command
    (
        while true; do
            sleep 60
        done
    ) >> "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    log_info "Started with PID $pid"
    log_info "Logs: $LOG_FILE"
    log_info "Endpoint: http://${SERVICE_HOST}:${SERVICE_PORT}"
}

# ============================================
# STANDARD COMMANDS
# ============================================

cmd_serve() {
    ensure_dirs

    if is_running; then
        log_warn "${SERVICE_NAME} is already running (PID: $(get_pid))"
        return 1
    fi

    start_service
}

cmd_stop() {
    if ! is_running; then
        log_warn "${SERVICE_NAME} is not running"
        return 0
    fi

    local pid=$(get_pid)
    log_info "Stopping ${SERVICE_NAME} (PID: $pid)..."

    kill "$pid" 2>/dev/null || true

    # Wait for graceful shutdown
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 30 ]]; do
        sleep 1
        ((count++))
    done

    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        log_warn "Forcing shutdown..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    log_info "Stopped"
}

cmd_restart() {
    cmd_stop
    sleep 2
    cmd_serve
}

cmd_status() {
    echo ""
    echo -e "${BLUE}=== ${SERVICE_DESCRIPTION} ===${NC}"
    echo ""

    if is_running; then
        local pid=$(get_pid)
        echo -e "Status:   ${GREEN}Running${NC}"
        echo "PID:      $pid"
        echo "Endpoint: http://${SERVICE_HOST}:${SERVICE_PORT}"
        echo ""

        # Show process info
        echo "Process:"
        ps -p "$pid" -o pid,user,%cpu,%mem,etime,command --no-headers 2>/dev/null || true
        echo ""

        # Show port binding
        if command -v ss &>/dev/null; then
            echo "Port ${SERVICE_PORT}:"
            ss -tlnp | grep ":${SERVICE_PORT}" || echo "  (not yet bound)"
        fi
    else
        echo -e "Status:   ${RED}Stopped${NC}"
    fi

    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
}

cmd_logs() {
    local lines="${1:-50}"

    if [[ ! -f "$LOG_FILE" ]]; then
        log_warn "No log file found at $LOG_FILE"
        return 1
    fi

    echo "=== Last $lines lines of $LOG_FILE ==="
    tail -n "$lines" "$LOG_FILE"
}

cmd_logs_follow() {
    if [[ ! -f "$LOG_FILE" ]]; then
        log_warn "No log file found at $LOG_FILE"
        return 1
    fi

    echo "=== Following $LOG_FILE (Ctrl+C to stop) ==="
    tail -f "$LOG_FILE"
}

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "${SERVICE_DESCRIPTION}"
    echo ""
    echo "Commands:"
    echo "  serve     Start the service"
    echo "  stop      Stop the service"
    echo "  restart   Restart the service"
    echo "  status    Show service status"
    echo "  logs [n]  Show last n log lines (default: 50)"
    echo "  follow    Follow log output"
    echo "  help      Show this help"
    echo ""
    echo "Configuration:"
    echo "  Port:     ${SERVICE_PORT}"
    echo "  Log:      ${LOG_FILE}"
    echo "  PID:      ${PID_FILE}"
    echo ""
}

# Main
case "${1:-help}" in
    serve|start)
        cmd_serve
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs "${2:-50}"
        ;;
    follow)
        cmd_logs_follow
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
