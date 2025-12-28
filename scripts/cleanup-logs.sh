#!/bin/bash
# =============================================================================
# cleanup-logs.sh - Docker Container Log Cleanup Utility
# =============================================================================
# Description: Reports container log sizes and optionally truncates logs.
#              Supports dry-run mode for safe size reporting.
# Usage: ./cleanup-logs.sh [--dry-run] [--force] [--help]
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/cleanup-logs.log"

# Default settings
DRY_RUN=true
# shellcheck disable=SC2034
FORCE=false # Used to indicate force mode was explicitly requested

# Container prefixes to clean
CONTAINER_PREFIX="n8n-"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [cleanup-logs] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [cleanup-logs] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [cleanup-logs] $1" | tee -a "$LOG_FILE"
}

# shellcheck disable=SC2329
log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [cleanup-logs] $1" | tee -a "$LOG_FILE"
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Report and optionally clean Docker container logs.

Options:
  --dry-run     Report log sizes without cleaning (default)
  --force       Actually truncate container logs (requires sudo)
  --help, -h    Show this help message

Behavior:
  By default, runs in dry-run mode showing log sizes.
  Use --force to actually truncate the log files.

Exit Codes:
  0  Success
  1  Error (docker not running, permission denied, etc.)

Examples:
  ./cleanup-logs.sh              # Show log sizes (dry-run)
  ./cleanup-logs.sh --dry-run    # Explicitly dry-run
  sudo ./cleanup-logs.sh --force # Actually truncate logs

Note:
  Log truncation requires sudo access because Docker log files
  are owned by root in /var/lib/docker/containers/.
EOF
}

# Get Docker container log path
get_log_path() {
	local container_id="$1"
	echo "/var/lib/docker/containers/${container_id}/${container_id}-json.log"
}

# Calculate human-readable size
human_size() {
	local bytes="$1"
	if [[ $bytes -ge 1073741824 ]]; then
		echo "$(echo "scale=2; $bytes / 1073741824" | bc)G"
	elif [[ $bytes -ge 1048576 ]]; then
		echo "$(echo "scale=2; $bytes / 1048576" | bc)M"
	elif [[ $bytes -ge 1024 ]]; then
		echo "$(echo "scale=2; $bytes / 1024" | bc)K"
	else
		echo "${bytes}B"
	fi
}

# Get container log size in bytes
get_log_size() {
	local container_id="$1"
	local log_path
	log_path=$(get_log_path "$container_id")

	if [[ -f "$log_path" ]]; then
		stat --printf="%s" "$log_path" 2>/dev/null || echo "0"
	else
		echo "0"
	fi
}

# List container log sizes
list_log_sizes() {
	log_info "Scanning container logs..."
	echo ""

	local total_bytes=0
	local container_count=0

	printf "%-40s %15s %s\n" "CONTAINER" "SIZE" "LOG PATH"
	printf "%s\n" "$(printf '=%.0s' {1..80})"

	# Get all running container IDs and names
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue

		local container_id container_name
		container_id=$(echo "$line" | awk '{print $1}')
		container_name=$(echo "$line" | awk '{print $2}')

		# Filter by prefix if set
		if [[ -n "$CONTAINER_PREFIX" ]] && [[ ! "$container_name" =~ ^${CONTAINER_PREFIX} ]]; then
			continue
		fi

		local log_path log_size_bytes log_size_human
		log_path=$(get_log_path "$container_id")
		log_size_bytes=$(get_log_size "$container_id")
		log_size_human=$(human_size "$log_size_bytes")

		printf "%-40s %15s %s\n" "$container_name" "$log_size_human" "$log_path"

		total_bytes=$((total_bytes + log_size_bytes))
		((container_count++))

	done < <(docker ps --format "{{.ID}} {{.Names}}" 2>/dev/null)

	printf "%s\n" "$(printf '=%.0s' {1..80})"
	printf "%-40s %15s\n" "TOTAL ($container_count containers)" "$(human_size $total_bytes)"
	echo ""

	return 0
}

# Truncate container logs
truncate_logs() {
	if [[ "$DRY_RUN" == "true" ]]; then
		log_info "Dry-run mode: No logs will be truncated"
		list_log_sizes
		log_info "To actually truncate logs, run: sudo ./cleanup-logs.sh --force"
		return 0
	fi

	# Check for root/sudo
	if [[ $EUID -ne 0 ]]; then
		log_error "Log truncation requires sudo. Run: sudo ./cleanup-logs.sh --force"
		return 1
	fi

	log_info "Truncating container logs..."
	echo ""

	local truncated_count=0
	local total_freed=0

	while IFS= read -r line; do
		[[ -z "$line" ]] && continue

		local container_id container_name
		container_id=$(echo "$line" | awk '{print $1}')
		container_name=$(echo "$line" | awk '{print $2}')

		# Filter by prefix if set
		if [[ -n "$CONTAINER_PREFIX" ]] && [[ ! "$container_name" =~ ^${CONTAINER_PREFIX} ]]; then
			continue
		fi

		local log_path log_size_bytes
		log_path=$(get_log_path "$container_id")
		log_size_bytes=$(get_log_size "$container_id")

		if [[ -f "$log_path" ]] && [[ $log_size_bytes -gt 0 ]]; then
			# Truncate the log file
			if truncate -s 0 "$log_path" 2>/dev/null; then
				log_success "Truncated $container_name: freed $(human_size "$log_size_bytes")"
				total_freed=$((total_freed + log_size_bytes))
				((truncated_count++))
			else
				log_error "Failed to truncate $container_name"
			fi
		fi

	done < <(docker ps --format "{{.ID}} {{.Names}}" 2>/dev/null)

	echo ""
	log_success "Truncated $truncated_count container logs, freed $(human_size $total_freed)"

	return 0
}

# Check Docker is available
check_docker() {
	if ! command -v docker &>/dev/null; then
		log_error "Docker command not found"
		return 1
	fi
	if ! docker info &>/dev/null; then
		log_error "Docker daemon not running or not accessible"
		return 1
	fi
	return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	# Ensure log directory exists
	mkdir -p "$(dirname "$LOG_FILE")"

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--force)
			DRY_RUN=false
			# shellcheck disable=SC2034
			FORCE=true
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
	log_info "Starting log cleanup"
	log_info "Mode: $(if [[ "$DRY_RUN" == "true" ]]; then echo "dry-run"; else echo "force"; fi)"
	log_info "=========================================="

	# Check Docker
	if ! check_docker; then
		exit 1
	fi

	# Show current sizes and optionally truncate
	if [[ "$DRY_RUN" == "true" ]]; then
		list_log_sizes
	else
		truncate_logs
	fi

	exit 0
}

main "$@"
