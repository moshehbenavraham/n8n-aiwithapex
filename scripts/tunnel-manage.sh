#!/bin/bash
# =============================================================================
# tunnel-manage.sh - Unified ngrok Tunnel Management
# =============================================================================
# Description: Manages ngrok tunnel operations (start, stop, status, restart)
#              for the n8n stack with Docker Compose integration
# Usage: ./tunnel-manage.sh <command> [options]
# Exit Codes: 0=success, 1=error, 2=tunnel not connected
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/tunnel-manage.log"

# Source environment variables
# shellcheck source=/dev/null
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	source "${PROJECT_DIR}/.env"
fi

# ngrok configuration
NGROK_CONTAINER="n8n-ngrok"
NGROK_SERVICE="ngrok"
NGROK_API_URL="http://localhost:${NGROK_INSPECTOR_PORT:-4040}/api"
API_TIMEOUT=5
STARTUP_WAIT=10

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-manage] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-manage] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-manage] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-manage] $1" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# Help Function
# -----------------------------------------------------------------------------
show_help() {
	cat <<EOF
Usage: $(basename "$0") <command> [options]

Unified management for ngrok tunnel operations.

Commands:
  start       Start the ngrok tunnel (docker compose up ngrok)
  stop        Stop the ngrok tunnel (docker compose stop ngrok)
  status      Show tunnel status and connection info
  restart     Restart the ngrok tunnel (stop + start)
  help        Show this help message

Options:
  -h, --help  Show this help message

Exit Codes:
  0  Success / Tunnel connected
  1  Error (container issue, API unreachable)
  2  Tunnel not connected

Examples:
  ./tunnel-manage.sh start      # Start ngrok tunnel
  ./tunnel-manage.sh stop       # Stop ngrok tunnel
  ./tunnel-manage.sh status     # Check tunnel status
  ./tunnel-manage.sh restart    # Restart tunnel
  ./tunnel-manage.sh -h         # Show help

Notes:
  - Uses docker compose to manage the ngrok service
  - Queries ngrok API at localhost:4040 for status info
  - Logs operations to logs/tunnel-manage.log
EOF
}

# -----------------------------------------------------------------------------
# Check Functions
# -----------------------------------------------------------------------------

# Check if ngrok container is running
check_ngrok_container() {
	local status
	status=$(docker inspect --format='{{.State.Status}}' "$NGROK_CONTAINER" 2>/dev/null)

	if [[ "$status" == "running" ]]; then
		return 0
	else
		return 1
	fi
}

# Check if ngrok container is healthy
check_ngrok_healthy() {
	local health
	health=$(docker inspect --format='{{.State.Health.Status}}' "$NGROK_CONTAINER" 2>/dev/null)

	if [[ "$health" == "healthy" ]]; then
		return 0
	else
		return 1
	fi
}

# Check if ngrok API is reachable
check_ngrok_api() {
	local http_code
	http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time "$API_TIMEOUT" "${NGROK_API_URL}/tunnels" 2>/dev/null)

	if [[ "$http_code" == "200" ]]; then
		return 0
	else
		return 1
	fi
}

# Get tunnel information from ngrok API
get_tunnel_info() {
	curl -sf --max-time "$API_TIMEOUT" "${NGROK_API_URL}/tunnels" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Tunnel Operations
# -----------------------------------------------------------------------------

# Start the ngrok tunnel
tunnel_start() {
	log_info "Starting ngrok tunnel..."

	# Check if already running
	if check_ngrok_container; then
		log_warn "ngrok container is already running"
		if check_ngrok_api; then
			log_success "Tunnel is connected"
			return 0
		else
			log_warn "Container running but tunnel not connected, will restart"
			tunnel_stop
		fi
	fi

	# Start the container using docker compose
	if ! docker compose up -d "$NGROK_SERVICE" 2>&1 | tee -a "$LOG_FILE"; then
		log_error "Failed to start ngrok container"
		return 1
	fi

	# Wait for container to be healthy
	log_info "Waiting for ngrok to initialize (${STARTUP_WAIT}s)..."
	local waited=0
	while [[ $waited -lt $STARTUP_WAIT ]]; do
		sleep 1
		((waited++))

		if check_ngrok_healthy && check_ngrok_api; then
			log_success "ngrok tunnel started and connected"
			tunnel_status
			return 0
		fi
	done

	# Check final state
	if check_ngrok_container; then
		if check_ngrok_api; then
			log_success "ngrok tunnel started and connected"
			tunnel_status
			return 0
		else
			log_warn "ngrok container running but API not reachable yet"
			log_info "Tunnel may still be initializing. Try 'tunnel-manage.sh status' in a moment."
			return 0
		fi
	else
		log_error "ngrok container failed to start"
		return 1
	fi
}

# Stop the ngrok tunnel
tunnel_stop() {
	log_info "Stopping ngrok tunnel..."

	if ! check_ngrok_container; then
		log_warn "ngrok container is not running"
		return 0
	fi

	# Stop the container using docker compose
	if ! docker compose stop "$NGROK_SERVICE" 2>&1 | tee -a "$LOG_FILE"; then
		log_error "Failed to stop ngrok container"
		return 1
	fi

	# Verify stopped
	sleep 1
	if check_ngrok_container; then
		log_error "ngrok container still running after stop command"
		return 1
	fi

	log_success "ngrok tunnel stopped"
	return 0
}

# Show tunnel status
tunnel_status() {
	# Check container state
	if ! check_ngrok_container; then
		log_error "ngrok container ($NGROK_CONTAINER) is not running"
		echo ""
		echo "To start the tunnel: ./tunnel-manage.sh start"
		return 1
	fi

	# Check health
	local health_status="unknown"
	if check_ngrok_healthy; then
		health_status="healthy"
	else
		health_status="unhealthy"
	fi

	# Check API
	if ! check_ngrok_api; then
		log_error "ngrok API not reachable at ${NGROK_API_URL}"
		echo ""
		echo "Container Status: running"
		echo "Health: $health_status"
		echo "API: unreachable"
		return 1
	fi

	# Get tunnel information
	local tunnel_data
	tunnel_data=$(get_tunnel_info)

	if [[ -z "$tunnel_data" ]] || [[ "$tunnel_data" == "null" ]]; then
		log_error "No tunnel data available"
		return 1
	fi

	local tunnel_count
	tunnel_count=$(echo "$tunnel_data" | jq -r '.tunnels | length' 2>/dev/null)

	if [[ "$tunnel_count" -eq 0 ]] || [[ "$tunnel_count" == "null" ]]; then
		log_warn "No active tunnels found"
		return 2
	fi

	# Display status
	echo "=========================================="
	echo "ngrok Tunnel Status"
	echo "=========================================="
	echo ""
	echo "Container: $NGROK_CONTAINER"
	echo "Health: $health_status"
	echo "Active Tunnels: $tunnel_count"
	echo ""

	# Display each tunnel
	echo "$tunnel_data" | jq -r '.tunnels[] | "Endpoint: \(.name)\n  URL: \(.public_url)\n  Protocol: \(.proto)\n  Backend: \(.config.addr)\n"' 2>/dev/null

	# Display metrics if available
	local metrics
	metrics=$(echo "$tunnel_data" | jq -r '.tunnels[0].metrics // empty' 2>/dev/null)

	if [[ -n "$metrics" ]] && [[ "$metrics" != "null" ]]; then
		echo "Metrics:"
		echo "$metrics" | jq -r '  "  Connections: \(.conns.count // 0)\n  Requests: \(.http.count // 0)"' 2>/dev/null
	fi

	echo ""
	echo "=========================================="
	log_success "Tunnel is connected and healthy"
	return 0
}

# Restart the ngrok tunnel
tunnel_restart() {
	log_info "Restarting ngrok tunnel..."

	tunnel_stop
	# Note: We continue even if stop fails (container may already be stopped)

	# Small delay between stop and start
	sleep 2

	tunnel_start
	local start_result=$?

	if [[ $start_result -eq 0 ]]; then
		log_success "ngrok tunnel restarted successfully"
		return 0
	else
		log_error "Failed to restart ngrok tunnel"
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	local command=""

	# Ensure log directory exists
	mkdir -p "$(dirname "$LOG_FILE")"

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help | help)
			show_help
			exit 0
			;;
		start | stop | status | restart)
			command="$1"
			shift
			;;
		*)
			log_error "Unknown option or command: $1"
			echo ""
			show_help
			exit 1
			;;
		esac
	done

	# Require a command
	if [[ -z "$command" ]]; then
		log_error "No command specified"
		echo ""
		show_help
		exit 1
	fi

	# Check docker is available
	if ! docker info &>/dev/null; then
		log_error "Docker is not available or not running"
		exit 1
	fi

	# Check docker compose is available
	if ! docker compose version &>/dev/null; then
		log_error "docker compose is not available"
		exit 1
	fi

	# Execute command
	case "$command" in
	start)
		tunnel_start
		exit $?
		;;
	stop)
		tunnel_stop
		exit $?
		;;
	status)
		tunnel_status
		exit $?
		;;
	restart)
		tunnel_restart
		exit $?
		;;
	esac
}

main "$@"
