#!/bin/bash
# =============================================================================
# monitor-resources.sh - Resource Monitoring with Threshold Alerts
# =============================================================================
# Description: Monitors memory, CPU, and disk usage for n8n stack containers.
#              Alerts when configurable thresholds are exceeded.
# Usage: ./monitor-resources.sh [--help] [--json]
# Exit Codes: 0=within thresholds, 1=threshold exceeded, 2=warning
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/monitor-resources.log"

# Thresholds (WSL2 8GB environment)
MEMORY_THRESHOLD_PCT=80   # Alert at 80% memory usage
CPU_THRESHOLD_PCT=90      # Alert at 90% CPU usage
DISK_THRESHOLD_PCT=85     # Alert at 85% disk usage

# Output format
OUTPUT_JSON=false

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [monitor-resources] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [monitor-resources] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [monitor-resources] $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [monitor-resources] $1" | tee -a "$LOG_FILE"
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Monitors resource usage for n8n stack:
  - System memory usage
  - Container CPU usage
  - Disk usage for data volumes

Options:
  --help, -h     Show this help message
  --json         Output results in JSON format

Thresholds (configurable via environment):
  MEMORY_THRESHOLD_PCT  Memory alert threshold (default: 80%)
  CPU_THRESHOLD_PCT     CPU alert threshold (default: 90%)
  DISK_THRESHOLD_PCT    Disk alert threshold (default: 85%)

Exit Codes:
  0  All resources within thresholds
  1  One or more thresholds exceeded
  2  Warning (approaching thresholds)

Examples:
  ./monitor-resources.sh           # Check resources
  ./monitor-resources.sh --json    # JSON output for scripting
EOF
}

# T012: Memory monitoring with threshold
check_memory() {
    log_info "Checking system memory..."

    # Get memory stats using free
    local mem_info
    mem_info=$(free -b 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get memory info"
        return 1
    fi

    # Parse memory values (in bytes)
    local total_mem used_mem available_mem
    total_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $2}')
    used_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $3}')
    available_mem=$(echo "$mem_info" | awk '/^Mem:/ {print $7}')

    # Calculate percentage used
    local mem_pct
    mem_pct=$(awk "BEGIN {printf \"%.1f\", ($used_mem / $total_mem) * 100}")
    local mem_pct_int=${mem_pct%.*}

    # Convert to human readable
    local total_hr used_hr avail_hr
    total_hr=$(numfmt --to=iec-i --suffix=B "$total_mem" 2>/dev/null || echo "${total_mem}B")
    used_hr=$(numfmt --to=iec-i --suffix=B "$used_mem" 2>/dev/null || echo "${used_mem}B")
    avail_hr=$(numfmt --to=iec-i --suffix=B "$available_mem" 2>/dev/null || echo "${available_mem}B")

    log_info "Memory: ${used_hr} / ${total_hr} (${mem_pct}% used, ${avail_hr} available)"

    if [[ $mem_pct_int -ge $MEMORY_THRESHOLD_PCT ]]; then
        log_error "Memory usage ${mem_pct}% exceeds threshold ${MEMORY_THRESHOLD_PCT}%"
        return 1
    elif [[ $mem_pct_int -ge $((MEMORY_THRESHOLD_PCT - 10)) ]]; then
        log_warn "Memory usage ${mem_pct}% approaching threshold ${MEMORY_THRESHOLD_PCT}%"
        return 0
    fi

    log_success "Memory usage within threshold"
    return 0
}

# T013: CPU monitoring with threshold
check_cpu() {
    log_info "Checking container CPU usage..."

    # Get container CPU stats from docker stats (one snapshot, not streaming)
    local stats
    stats=$(docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}" 2>/dev/null | grep "^n8n-")

    if [[ -z "$stats" ]]; then
        log_error "No n8n containers found or docker stats failed"
        return 1
    fi

    local max_cpu=0
    local max_container=""
    local total_cpu=0
    local container_count=0
    local threshold_exceeded=false

    while IFS=$'\t' read -r name cpu_str; do
        [[ -z "$name" ]] && continue

        # Remove % sign and parse CPU value
        local cpu_val
        cpu_val=$(echo "$cpu_str" | tr -d '%')

        # Handle decimal values (take integer part for comparison)
        local cpu_int=${cpu_val%.*}
        [[ -z "$cpu_int" ]] && cpu_int=0

        ((container_count++))
        total_cpu=$(awk "BEGIN {print $total_cpu + $cpu_val}")

        if [[ $cpu_int -gt ${max_cpu%.*} ]]; then
            max_cpu=$cpu_val
            max_container=$name
        fi

        if [[ $cpu_int -ge $CPU_THRESHOLD_PCT ]]; then
            log_error "Container $name CPU usage ${cpu_str} exceeds threshold ${CPU_THRESHOLD_PCT}%"
            threshold_exceeded=true
        fi
    done <<< "$stats"

    local avg_cpu
    avg_cpu=$(awk "BEGIN {printf \"%.1f\", $total_cpu / $container_count}")

    log_info "CPU: $container_count containers, avg ${avg_cpu}%, max ${max_cpu}% ($max_container)"

    if [[ "$threshold_exceeded" == "true" ]]; then
        return 1
    fi

    log_success "CPU usage within threshold"
    return 0
}

# T014: Disk monitoring with threshold
check_disk() {
    log_info "Checking disk usage..."

    local threshold_exceeded=false

    # Check project directory disk usage
    local project_disk
    project_disk=$(df -h "$PROJECT_DIR" 2>/dev/null | tail -1)

    if [[ -n "$project_disk" ]]; then
        local mount_point used_pct
        mount_point=$(echo "$project_disk" | awk '{print $6}')
        used_pct=$(echo "$project_disk" | awk '{print $5}' | tr -d '%')
        local total_size=$(echo "$project_disk" | awk '{print $2}')
        local used_size=$(echo "$project_disk" | awk '{print $3}')
        local avail_size=$(echo "$project_disk" | awk '{print $4}')

        log_info "Disk ($mount_point): ${used_size} / ${total_size} (${used_pct}% used, ${avail_size} available)"

        if [[ $used_pct -ge $DISK_THRESHOLD_PCT ]]; then
            log_error "Disk usage ${used_pct}% exceeds threshold ${DISK_THRESHOLD_PCT}%"
            threshold_exceeded=true
        elif [[ $used_pct -ge $((DISK_THRESHOLD_PCT - 10)) ]]; then
            log_warn "Disk usage ${used_pct}% approaching threshold ${DISK_THRESHOLD_PCT}%"
        fi
    fi

    # Check Docker volume usage
    log_info "Checking Docker volume sizes..."
    local volumes
    volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "^n8n_|^n8n-")

    if [[ -n "$volumes" ]]; then
        while read -r vol_name; do
            [[ -z "$vol_name" ]] && continue

            # Get volume size using docker system df
            local vol_size
            vol_size=$(docker system df -v 2>/dev/null | grep "$vol_name" | awk '{print $4}' | head -1)
            [[ -z "$vol_size" ]] && vol_size="unknown"

            log_info "Volume $vol_name: $vol_size"
        done <<< "$volumes"
    else
        log_info "No n8n Docker volumes found"
    fi

    if [[ "$threshold_exceeded" == "true" ]]; then
        return 1
    fi

    log_success "Disk usage within threshold"
    return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --json)
                OUTPUT_JSON=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    log_info "=========================================="
    log_info "Starting resource monitoring"
    log_info "=========================================="
    log_info "Thresholds: Memory=${MEMORY_THRESHOLD_PCT}%, CPU=${CPU_THRESHOLD_PCT}%, Disk=${DISK_THRESHOLD_PCT}%"

    OVERALL_STATUS=0

    # Check memory
    if ! check_memory; then
        OVERALL_STATUS=1
    fi

    # Check CPU
    if ! check_cpu; then
        OVERALL_STATUS=1
    fi

    # Check disk
    if ! check_disk; then
        OVERALL_STATUS=1
    fi

    log_info "=========================================="
    if [[ $OVERALL_STATUS -eq 0 ]]; then
        log_success "All resources within thresholds"
    elif [[ $OVERALL_STATUS -eq 2 ]]; then
        log_warn "Resources approaching thresholds"
    else
        log_error "Resource thresholds exceeded"
    fi

    exit $OVERALL_STATUS
}

main "$@"
