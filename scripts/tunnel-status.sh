#!/bin/bash
# =============================================================================
# tunnel-status.sh - ngrok Tunnel Status and Information
# =============================================================================
# Description: Retrieves and displays detailed ngrok tunnel status including
#              tunnel URL, connection state, metrics, and latency information
# Usage: ./tunnel-status.sh [--help] [--json]
# Exit Codes: 0=connected, 1=error, 2=tunnel not connected
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/tunnel-status.log"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	source "${PROJECT_DIR}/.env"
fi

# ngrok API configuration
NGROK_API_URL="http://localhost:${NGROK_INSPECTOR_PORT:-4040}/api"
API_TIMEOUT=5

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-status] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-status] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-status] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [tunnel-status] $1" | tee -a "$LOG_FILE"
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Displays detailed ngrok tunnel status and information.

Options:
  --help, -h     Show this help message
  --json, -j     Output in JSON format

Exit Codes:
  0  Tunnel connected and healthy
  1  Error (API unreachable, container not running)
  2  Tunnel not connected

Information Displayed:
  - Tunnel URL (public ngrok URL)
  - Tunnel protocol (https/http)
  - Backend address (internal Docker target)
  - Connection status
  - Session metrics (requests, bytes transferred)

Examples:
  ./tunnel-status.sh           # Show tunnel status
  ./tunnel-status.sh --json    # Output as JSON
  ./tunnel-status.sh --help    # Show this help
EOF
}

# Check if ngrok container is running
check_container_running() {
	if ! docker inspect --format='{{.State.Status}}' n8n-ngrok 2>/dev/null | grep -q "running"; then
		return 1
	fi
	return 0
}

# Check if ngrok API is reachable
check_api_reachable() {
	local http_code
	http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time "$API_TIMEOUT" "${NGROK_API_URL}/tunnels" 2>/dev/null)
	[[ "$http_code" == "200" ]]
}

# Get tunnel information from ngrok API
get_tunnel_info() {
	curl -sf --max-time "$API_TIMEOUT" "${NGROK_API_URL}/tunnels" 2>/dev/null
}

# Parse and display tunnel status in human-readable format
display_tunnel_status() {
	local tunnel_data="$1"

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

	echo "=========================================="
	echo "ngrok Tunnel Status"
	echo "=========================================="
	echo ""

	# Iterate through tunnels
	echo "$tunnel_data" | jq -r '.tunnels[] | "Tunnel: \(.name)\n  URL: \(.public_url)\n  Protocol: \(.proto)\n  Backend: \(.config.addr)\n"' 2>/dev/null

	# Display metrics if available
	local metrics
	metrics=$(curl -sf --max-time "$API_TIMEOUT" "${NGROK_API_URL}/tunnels" 2>/dev/null | jq -r '.tunnels[0].metrics // empty' 2>/dev/null)

	if [[ -n "$metrics" ]] && [[ "$metrics" != "null" ]]; then
		echo "Metrics:"
		echo "$metrics" | jq -r '  "  Connections: \(.conns.count // 0)\n  Requests: \(.http.count // 0)\n  Bytes In: \(.conns.gauge // 0)"' 2>/dev/null
	fi

	echo ""
	echo "=========================================="
	log_success "Tunnel is connected and healthy"
	return 0
}

# Output tunnel status in JSON format
display_json() {
	local tunnel_data="$1"

	if [[ -z "$tunnel_data" ]] || [[ "$tunnel_data" == "null" ]]; then
		echo '{"status":"error","message":"No tunnel data available"}'
		return 1
	fi

	local tunnel_count
	tunnel_count=$(echo "$tunnel_data" | jq -r '.tunnels | length' 2>/dev/null)

	if [[ "$tunnel_count" -eq 0 ]] || [[ "$tunnel_count" == "null" ]]; then
		echo '{"status":"disconnected","message":"No active tunnels"}'
		return 2
	fi

	# Build JSON output
	echo "$tunnel_data" | jq '{
		status: "connected",
		tunnel_count: (.tunnels | length),
		tunnels: [.tunnels[] | {
			name: .name,
			url: .public_url,
			protocol: .proto,
			backend: .config.addr
		}]
	}' 2>/dev/null

	return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	local json_output=false

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		--json | -j)
			json_output=true
			shift
			;;
		*)
			log_error "Unknown option: $1"
			show_help
			exit 1
			;;
		esac
	done

	# Check if ngrok container is running
	if ! check_container_running; then
		if $json_output; then
			echo '{"status":"error","message":"ngrok container not running"}'
		else
			log_error "ngrok container (n8n-ngrok) is not running"
		fi
		exit 1
	fi

	# Check if API is reachable
	if ! check_api_reachable; then
		if $json_output; then
			echo '{"status":"error","message":"ngrok API not reachable"}'
		else
			log_error "ngrok API not reachable at ${NGROK_API_URL}"
		fi
		exit 1
	fi

	# Get tunnel information
	local tunnel_data
	tunnel_data=$(get_tunnel_info)

	# Display based on output format
	if $json_output; then
		display_json "$tunnel_data"
	else
		display_tunnel_status "$tunnel_data"
	fi

	exit $?
}

main "$@"
