#!/bin/bash
# =============================================================================
# queue-depth.sh - Query Redis Bull queue depth for n8n workers
# =============================================================================
# Description: Retrieves the total count of pending jobs from Redis Bull queues.
#              Used by worker-autoscale.sh to make scaling decisions.
# Usage: ./queue-depth.sh [--json] [--verbose]
# Exit Codes: 0=success (outputs depth), 1=Redis connection error
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

# Redis connection settings (from .env or defaults)
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6386}"
REDIS_CONTAINER="${REDIS_CONTAINER:-n8n-redis}"

# Bull queue configuration
# n8n uses "jobs" as the Bull queue name
BULL_QUEUE_NAME="${BULL_QUEUE_NAME:-jobs}"

# =============================================================================
# Helper Functions
# =============================================================================

show_usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Query Redis Bull queue depth for n8n worker scaling decisions.

Options:
  --json      Output in JSON format
  --verbose   Show detailed queue breakdown
  --help      Show this help message

Exit Codes:
  0  Success - outputs queue depth (integer or JSON)
  1  Error - Redis connection failed or other error

Examples:
  $(basename "$0")              # Returns total pending jobs count
  $(basename "$0") --json       # Returns {"depth": N, "wait": N, "delayed": N}
  $(basename "$0") --verbose    # Shows breakdown of each queue
EOF
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [queue-depth] $1" >&2
}

# Execute Redis command via docker exec
# Arguments: $@ - Redis CLI arguments
# Returns: Command output or empty on failure
redis_cmd() {
	docker exec "${REDIS_CONTAINER}" redis-cli -h localhost -p "${REDIS_PORT}" "$@" 2>/dev/null
}

# Test Redis connectivity
# Returns: 0 if connected, 1 if failed
test_redis_connection() {
	local result
	result=$(redis_cmd PING 2>/dev/null)
	if [[ "$result" == "PONG" ]]; then
		return 0
	else
		return 1
	fi
}

# Get length of a Redis list
# Arguments: $1 - key name
# Returns: Length (integer) or 0 if key doesn't exist
get_list_length() {
	local key="$1"
	local length
	length=$(redis_cmd LLEN "$key" 2>/dev/null)
	# Return 0 if empty or non-numeric
	if [[ "$length" =~ ^[0-9]+$ ]]; then
		echo "$length"
	else
		echo "0"
	fi
}

# Get cardinality of a Redis sorted set
# Arguments: $1 - key name
# Returns: Cardinality (integer) or 0 if key doesn't exist
get_zset_cardinality() {
	local key="$1"
	local count
	count=$(redis_cmd ZCARD "$key" 2>/dev/null)
	# Return 0 if empty or non-numeric
	if [[ "$count" =~ ^[0-9]+$ ]]; then
		echo "$count"
	else
		echo "0"
	fi
}

# =============================================================================
# Main Functions
# =============================================================================

# Get queue depth breakdown
# Populates global variables: WAIT_COUNT, DELAYED_COUNT, PRIORITY_COUNT
get_queue_depths() {
	local queue_prefix="bull:${BULL_QUEUE_NAME}"

	# Waiting jobs (list)
	WAIT_COUNT=$(get_list_length "${queue_prefix}:wait")

	# Delayed jobs (sorted set)
	DELAYED_COUNT=$(get_zset_cardinality "${queue_prefix}:delayed")

	# Priority queue (sorted set, if exists)
	PRIORITY_COUNT=$(get_zset_cardinality "${queue_prefix}:priority")

	# Calculate total
	TOTAL_DEPTH=$((WAIT_COUNT + DELAYED_COUNT + PRIORITY_COUNT))
}

# Output queue depth in JSON format
output_json() {
	cat <<EOF
{"depth": ${TOTAL_DEPTH}, "wait": ${WAIT_COUNT}, "delayed": ${DELAYED_COUNT}, "priority": ${PRIORITY_COUNT}}
EOF
}

# Output queue depth with verbose breakdown
output_verbose() {
	echo "Queue Depth Report"
	echo "=================="
	echo "Queue Name: ${BULL_QUEUE_NAME}"
	echo ""
	echo "Breakdown:"
	echo "  Waiting:  ${WAIT_COUNT}"
	echo "  Delayed:  ${DELAYED_COUNT}"
	echo "  Priority: ${PRIORITY_COUNT}"
	echo "  --------"
	echo "  Total:    ${TOTAL_DEPTH}"
}

# =============================================================================
# Main
# =============================================================================
main() {
	local output_json=false
	local verbose=false

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--json)
			output_json=true
			shift
			;;
		--verbose)
			verbose=true
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

	# Test Redis connection
	if ! test_redis_connection; then
		log_error "Failed to connect to Redis at ${REDIS_CONTAINER}:${REDIS_PORT}"
		if [[ "$output_json" == true ]]; then
			echo '{"error": "Redis connection failed", "depth": -1}'
		fi
		exit 1
	fi

	# Get queue depths
	get_queue_depths

	# Output results
	if [[ "$output_json" == true ]]; then
		output_json
	elif [[ "$verbose" == true ]]; then
		output_verbose
	else
		# Default: just output the total depth
		echo "$TOTAL_DEPTH"
	fi

	exit 0
}

main "$@"
