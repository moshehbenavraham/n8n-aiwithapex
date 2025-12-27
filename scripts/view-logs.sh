#!/bin/bash
# =============================================================================
# view-logs.sh - Unified Log Viewer with Service Filtering
# =============================================================================
# Description: View logs from n8n stack containers with service filtering,
#              tail mode, and follow mode support.
# Usage: ./view-logs.sh [-s service] [-n lines] [-f] [--help]
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Valid services
VALID_SERVICES=("postgres" "redis" "n8n" "worker" "all")

# Default settings
SERVICE="all"
TAIL_LINES=100
FOLLOW_MODE=false

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [view-logs] $1" >&2
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [view-logs] $1" >&2
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

View logs from n8n stack containers.

Options:
  -s, --service SERVICE   Filter by service (postgres|redis|n8n|worker|all)
                          Default: all
  -n, --lines LINES       Number of lines to show (default: 100)
  -f, --follow            Follow log output (like tail -f)
  --help, -h              Show this help message

Services:
  postgres    PostgreSQL database logs
  redis       Redis cache logs
  n8n         n8n main application logs
  worker      n8n worker logs (all replicas)
  all         All services (default)

Exit Codes:
  0  Success
  1  Error (invalid service, docker not running, etc.)

Examples:
  ./view-logs.sh                      # Show last 100 lines from all services
  ./view-logs.sh -s n8n -n 50         # Last 50 lines from n8n
  ./view-logs.sh -s worker -f         # Follow worker logs
  ./view-logs.sh -s postgres -n 200   # Last 200 lines from postgres
EOF
}

# Validate service name
validate_service() {
	local svc="$1"
	for valid in "${VALID_SERVICES[@]}"; do
		if [[ "$svc" == "$valid" ]]; then
			return 0
		fi
	done
	return 1
}

# Map service name to docker compose service(s)
get_container_names() {
	local service="$1"

	case "$service" in
	postgres)
		echo "postgres"
		;;
	redis)
		echo "redis"
		;;
	n8n)
		echo "n8n"
		;;
	worker)
		echo "n8n-worker"
		;;
	all)
		echo "postgres redis n8n n8n-worker"
		;;
	esac
}

# T015/T016: View logs with service filtering, tail mode, and follow mode
view_service_logs() {
	# Check if docker compose is available
	if ! docker compose version &>/dev/null; then
		log_error "docker compose not available"
		return 1
	fi

	# Get the service names to query
	local services
	services=$(get_container_names "$SERVICE")

	if [[ -z "$services" ]]; then
		log_error "No services to show logs for"
		return 1
	fi

	# Build docker compose logs command
	local cmd_args=()
	cmd_args+=("--tail" "$TAIL_LINES")

	if [[ "$FOLLOW_MODE" == "true" ]]; then
		cmd_args+=("--follow")
	fi

	# Add timestamps for better readability
	cmd_args+=("--timestamps")

	log_info "Fetching logs for: $services"
	echo "" >&2

	# Execute docker compose logs with the service names
	# shellcheck disable=SC2086
	docker compose logs "${cmd_args[@]}" $services

	return $?
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		-s | --service)
			SERVICE="$2"
			if ! validate_service "$SERVICE"; then
				log_error "Invalid service: $SERVICE"
				log_error "Valid services: ${VALID_SERVICES[*]}"
				exit 1
			fi
			shift 2
			;;
		-n | --lines)
			TAIL_LINES="$2"
			if ! [[ "$TAIL_LINES" =~ ^[0-9]+$ ]]; then
				log_error "Lines must be a positive integer"
				exit 1
			fi
			shift 2
			;;
		-f | --follow)
			FOLLOW_MODE=true
			shift
			;;
		*)
			log_error "Unknown option: $1"
			show_help
			exit 1
			;;
		esac
	done

	log_info "Viewing logs: service=$SERVICE, lines=$TAIL_LINES, follow=$FOLLOW_MODE"

	view_service_logs

	exit 0
}

main "$@"
