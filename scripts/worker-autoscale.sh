#!/bin/bash
# =============================================================================
# worker-autoscale.sh - Auto-scale n8n workers based on queue depth
# =============================================================================
# Description: Monitors Redis Bull queue depth and scales workers up/down based
#              on configurable thresholds. Designed to run via cron every minute.
# Usage: ./worker-autoscale.sh [--dry-run] [--force] [--status]
# Exit Codes: 0=success, 1=error, 2=skipped (cooldown/disabled)
# =============================================================================
set -o pipefail

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck disable=SC1091
	source "${PROJECT_DIR}/.env"
fi

# Auto-scaling configuration (from .env or defaults)
AUTOSCALE_ENABLED="${AUTOSCALE_ENABLED:-true}"
AUTOSCALE_MIN_WORKERS="${AUTOSCALE_MIN_WORKERS:-1}"
AUTOSCALE_MAX_WORKERS="${AUTOSCALE_MAX_WORKERS:-10}"
AUTOSCALE_HIGH_THRESHOLD="${AUTOSCALE_HIGH_THRESHOLD:-20}"
AUTOSCALE_LOW_THRESHOLD="${AUTOSCALE_LOW_THRESHOLD:-5}"
AUTOSCALE_COOLDOWN_SECONDS="${AUTOSCALE_COOLDOWN_SECONDS:-120}"
AUTOSCALE_LOG_FILE="${AUTOSCALE_LOG_FILE:-logs/autoscale.log}"

# Resolve log file path
if [[ "${AUTOSCALE_LOG_FILE}" != /* ]]; then
	AUTOSCALE_LOG_FILE="${PROJECT_DIR}/${AUTOSCALE_LOG_FILE}"
fi

# Lock file and cooldown timestamp file
LOCK_FILE="/tmp/worker-autoscale.lock"
COOLDOWN_FILE="/tmp/worker-autoscale.last"
LOCK_TIMEOUT=300

# Worker service name in Docker Compose
WORKER_SERVICE="n8n-worker"

# =============================================================================
# Helper Functions
# =============================================================================

show_usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Auto-scale n8n workers based on Redis Bull queue depth.

Options:
  --dry-run   Show what would be done without making changes
  --force     Skip cooldown check and force evaluation
  --status    Display current scaling status and exit
  --help      Show this help message

Configuration (via .env):
  AUTOSCALE_ENABLED         Enable/disable auto-scaling (default: true)
  AUTOSCALE_MIN_WORKERS     Minimum worker count (default: 1)
  AUTOSCALE_MAX_WORKERS     Maximum worker count (default: 10)
  AUTOSCALE_HIGH_THRESHOLD  Queue depth to trigger scale-up (default: 20)
  AUTOSCALE_LOW_THRESHOLD   Queue depth to trigger scale-down (default: 5)
  AUTOSCALE_COOLDOWN_SECONDS Seconds between scaling operations (default: 120)

Exit Codes:
  0  Success - scaling action taken or not needed
  1  Error - failed to execute
  2  Skipped - cooldown active or auto-scaling disabled
EOF
}

log_info() {
	local msg
	msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') [worker-autoscale] $1"
	echo "$msg"
	echo "$msg" >>"${AUTOSCALE_LOG_FILE}"
}

log_warn() {
	local msg
	msg="[WARN] $(date '+%Y-%m-%d %H:%M:%S') [worker-autoscale] $1"
	echo "$msg"
	echo "$msg" >>"${AUTOSCALE_LOG_FILE}"
}

log_error() {
	local msg
	msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [worker-autoscale] $1"
	echo "$msg" >&2
	echo "$msg" >>"${AUTOSCALE_LOG_FILE}"
}

log_scale() {
	local msg
	msg="[SCALE] $(date '+%Y-%m-%d %H:%M:%S') [worker-autoscale] $1"
	echo "$msg"
	echo "$msg" >>"${AUTOSCALE_LOG_FILE}"
}

# Acquire lock file with timeout handling
# Returns: 0 if lock acquired, 1 if failed
acquire_lock() {
	local lock_age

	# Check if lock file exists
	if [[ -f "${LOCK_FILE}" ]]; then
		# Check if lock is stale (older than LOCK_TIMEOUT seconds)
		lock_age=$(($(date +%s) - $(stat -c %Y "${LOCK_FILE}" 2>/dev/null || echo 0)))
		if [[ ${lock_age} -gt ${LOCK_TIMEOUT} ]]; then
			log_warn "Stale lock file detected (${lock_age}s old), removing"
			rm -f "${LOCK_FILE}"
		else
			log_info "Lock file exists, another scaling operation in progress"
			return 1
		fi
	fi

	# Create lock file with PID
	echo $$ >"${LOCK_FILE}"
	return 0
}

# Release lock file (used in trap)
# shellcheck disable=SC2329
release_lock() {
	rm -f "${LOCK_FILE}"
}

# Check if cooldown period has elapsed
# Returns: 0 if cooldown elapsed or no previous scaling, 1 if still in cooldown
check_cooldown() {
	local last_scale_time
	local current_time
	local elapsed

	if [[ ! -f "${COOLDOWN_FILE}" ]]; then
		return 0
	fi

	last_scale_time=$(cat "${COOLDOWN_FILE}" 2>/dev/null || echo 0)
	current_time=$(date +%s)
	elapsed=$((current_time - last_scale_time))

	if [[ ${elapsed} -lt ${AUTOSCALE_COOLDOWN_SECONDS} ]]; then
		local remaining=$((AUTOSCALE_COOLDOWN_SECONDS - elapsed))
		log_info "Cooldown active: ${remaining}s remaining"
		return 1
	fi

	return 0
}

# Update cooldown timestamp
update_cooldown() {
	date +%s >"${COOLDOWN_FILE}"
}

# Get current queue depth using queue-depth.sh
# Returns: Queue depth (integer) or -1 on error
get_queue_depth() {
	local depth
	depth=$("${SCRIPT_DIR}/queue-depth.sh" 2>/dev/null)
	if [[ "$depth" =~ ^[0-9]+$ ]]; then
		echo "$depth"
	else
		echo "-1"
	fi
}

# Get current worker count from Docker Compose
# Returns: Worker count (integer) or -1 on error
get_worker_count() {
	local count
	count=$(docker compose -f "${PROJECT_DIR}/docker-compose.yml" ps --format json "${WORKER_SERVICE}" 2>/dev/null | grep -c '"State":"running"' || echo 0)

	# Alternative method if json format doesn't work
	if [[ "$count" == "0" ]]; then
		count=$(docker compose -f "${PROJECT_DIR}/docker-compose.yml" ps "${WORKER_SERVICE}" 2>/dev/null | grep -c "running" || echo 0)
	fi

	if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -gt 0 ]]; then
		echo "$count"
	else
		# Fallback: count containers directly
		count=$(docker ps --filter "name=n8n-n8n-worker" --format "{{.Names}}" 2>/dev/null | wc -l)
		echo "$count"
	fi
}

# Scale workers to target count
# Arguments: $1 - target worker count
# Returns: 0 on success, 1 on failure
scale_workers() {
	local target=$1
	local result

	log_scale "Scaling workers to ${target}"

	if result=$(docker compose -f "${PROJECT_DIR}/docker-compose.yml" up -d --scale "${WORKER_SERVICE}=${target}" --no-recreate 2>&1); then
		log_scale "Successfully scaled to ${target} workers"
		update_cooldown
		return 0
	else
		log_error "Failed to scale workers: ${result}"
		return 1
	fi
}

# Calculate target worker count based on queue depth
# Arguments: $1 - current worker count, $2 - queue depth
# Returns: Target worker count
calculate_target() {
	local current=$1
	local depth=$2
	local target=$current

	if [[ ${depth} -ge ${AUTOSCALE_HIGH_THRESHOLD} ]]; then
		# Scale up: add 1 worker for every HIGH_THRESHOLD jobs above threshold
		local jobs_above=$((depth - AUTOSCALE_HIGH_THRESHOLD))
		local workers_to_add=$(((jobs_above / AUTOSCALE_HIGH_THRESHOLD) + 1))
		target=$((current + workers_to_add))
	elif [[ ${depth} -le ${AUTOSCALE_LOW_THRESHOLD} ]] && [[ ${current} -gt ${AUTOSCALE_MIN_WORKERS} ]]; then
		# Scale down: remove 1 worker
		target=$((current - 1))
	fi

	# Enforce bounds
	if [[ ${target} -lt ${AUTOSCALE_MIN_WORKERS} ]]; then
		target=${AUTOSCALE_MIN_WORKERS}
	elif [[ ${target} -gt ${AUTOSCALE_MAX_WORKERS} ]]; then
		target=${AUTOSCALE_MAX_WORKERS}
	fi

	echo "$target"
}

# Display current status
show_status() {
	local current_workers
	local queue_depth
	local cooldown_remaining=0

	current_workers=$(get_worker_count)
	queue_depth=$(get_queue_depth)

	if [[ -f "${COOLDOWN_FILE}" ]]; then
		local last_scale_time
		local current_time
		last_scale_time=$(cat "${COOLDOWN_FILE}" 2>/dev/null || echo 0)
		current_time=$(date +%s)
		local elapsed=$((current_time - last_scale_time))
		if [[ ${elapsed} -lt ${AUTOSCALE_COOLDOWN_SECONDS} ]]; then
			cooldown_remaining=$((AUTOSCALE_COOLDOWN_SECONDS - elapsed))
		fi
	fi

	echo "Worker Auto-Scaling Status"
	echo "=========================="
	echo ""
	echo "Configuration:"
	echo "  Enabled:        ${AUTOSCALE_ENABLED}"
	echo "  Min Workers:    ${AUTOSCALE_MIN_WORKERS}"
	echo "  Max Workers:    ${AUTOSCALE_MAX_WORKERS}"
	echo "  High Threshold: ${AUTOSCALE_HIGH_THRESHOLD} jobs"
	echo "  Low Threshold:  ${AUTOSCALE_LOW_THRESHOLD} jobs"
	echo "  Cooldown:       ${AUTOSCALE_COOLDOWN_SECONDS}s"
	echo ""
	echo "Current State:"
	echo "  Workers:        ${current_workers}"
	echo "  Queue Depth:    ${queue_depth}"
	echo "  Cooldown Left:  ${cooldown_remaining}s"
	echo ""

	# Determine what action would be taken
	local target
	target=$(calculate_target "$current_workers" "$queue_depth")
	if [[ "$target" -gt "$current_workers" ]]; then
		echo "  Action:         Would scale UP to ${target} workers"
	elif [[ "$target" -lt "$current_workers" ]]; then
		echo "  Action:         Would scale DOWN to ${target} workers"
	else
		echo "  Action:         No scaling needed"
	fi
}

# =============================================================================
# Main
# =============================================================================
main() {
	local dry_run=false
	local force=false
	local status_only=false

	# Ensure log directory exists
	mkdir -p "$(dirname "${AUTOSCALE_LOG_FILE}")"

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=true
			shift
			;;
		--force)
			force=true
			shift
			;;
		--status)
			status_only=true
			shift
			;;
		--help)
			show_usage
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			show_usage
			exit 1
			;;
		esac
	done

	# Handle status display
	if [[ "$status_only" == true ]]; then
		show_status
		exit 0
	fi

	# Check if auto-scaling is enabled
	if [[ "${AUTOSCALE_ENABLED}" != "true" ]]; then
		log_info "Auto-scaling is disabled"
		exit 2
	fi

	# Acquire lock
	if ! acquire_lock; then
		exit 2
	fi

	# Ensure lock is released on exit
	trap release_lock EXIT

	# Check cooldown (unless forced)
	if [[ "$force" != true ]]; then
		if ! check_cooldown; then
			exit 2
		fi
	fi

	# Get current state
	local current_workers
	local queue_depth

	current_workers=$(get_worker_count)
	if [[ "$current_workers" -lt 0 ]]; then
		log_error "Failed to get current worker count"
		exit 1
	fi

	queue_depth=$(get_queue_depth)
	if [[ "$queue_depth" -lt 0 ]]; then
		log_error "Failed to get queue depth"
		exit 1
	fi

	log_info "Current state: ${current_workers} workers, ${queue_depth} jobs in queue"

	# Calculate target
	local target
	target=$(calculate_target "$current_workers" "$queue_depth")

	# Determine action
	if [[ "$target" -eq "$current_workers" ]]; then
		log_info "No scaling needed (target: ${target})"
		exit 0
	fi

	# Execute or simulate scaling
	if [[ "$dry_run" == true ]]; then
		if [[ "$target" -gt "$current_workers" ]]; then
			log_info "[DRY-RUN] Would scale UP from ${current_workers} to ${target} workers"
		else
			log_info "[DRY-RUN] Would scale DOWN from ${current_workers} to ${target} workers"
		fi
		exit 0
	fi

	# Perform scaling
	if [[ "$target" -gt "$current_workers" ]]; then
		log_scale "Scaling UP from ${current_workers} to ${target} workers (queue depth: ${queue_depth})"
	else
		log_scale "Scaling DOWN from ${current_workers} to ${target} workers (queue depth: ${queue_depth})"
	fi

	if scale_workers "$target"; then
		exit 0
	else
		exit 1
	fi
}

main "$@"
