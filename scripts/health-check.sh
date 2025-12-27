#!/bin/bash
# =============================================================================
# health-check.sh - Container and Endpoint Health Validation
# =============================================================================
# Description: Validates all n8n stack containers are running and healthy,
#              verifies /healthz endpoint, and checks worker replica count
# Usage: ./health-check.sh [--help]
# Exit Codes: 0=all healthy, 1=unhealthy, 2=warning (partial health)
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/health-check.log"

# Health check settings
HEALTHZ_URL="http://localhost:5678/healthz"
HEALTHZ_TIMEOUT=5
EXPECTED_WORKERS=5

# Container names (actual Docker container names)
REQUIRED_CONTAINERS=("n8n-postgres" "n8n-redis" "n8n-main" "n8n-ngrok")

# ngrok API configuration
NGROK_API_URL="http://localhost:${NGROK_INSPECTOR_PORT:-4040}/api"
NGROK_TIMEOUT=5

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [health-check] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [health-check] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [health-check] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [health-check] $1" | tee -a "$LOG_FILE"
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validates n8n stack health by checking:
  - Container running status (postgres, redis, n8n, n8n-worker)
  - Container health states (Docker HEALTHCHECK)
  - /healthz endpoint response
  - Worker replica count

Options:
  --help, -h     Show this help message

Exit Codes:
  0  All containers and endpoints healthy
  1  One or more critical failures
  2  Warning (partial health, e.g., fewer workers than expected)

Examples:
  ./health-check.sh           # Run full health check
  ./health-check.sh --help    # Show this help
EOF
}

# Check if Docker is available
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

# T009: Check container health using docker inspect
check_container_health() {
	log_info "Checking container health..."

	if ! check_docker; then
		return 1
	fi

	local failed=0
	local checked=0

	# Check required containers
	for container_name in "${REQUIRED_CONTAINERS[@]}"; do
		((checked++))

		# Check if container exists and is running
		local state
		if ! state=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null); then
			log_error "Container $container_name not found"
			((failed++))
			continue
		fi

		if [[ "$state" != "running" ]]; then
			log_error "Container $container_name is not running (state: $state)"
			((failed++))
			continue
		fi

		# Check health status if healthcheck is configured
		local health
		health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null)

		if [[ "$health" == "none" ]]; then
			log_info "Container $container_name: running (no healthcheck)"
		elif [[ "$health" == "healthy" ]]; then
			log_success "Container $container_name: healthy"
		elif [[ "$health" == "starting" ]]; then
			log_warn "Container $container_name: starting (health check pending)"
		else
			log_error "Container $container_name: unhealthy (health: $health)"
			((failed++))
		fi
	done

	if [[ $failed -gt 0 ]]; then
		log_error "Container health check: $failed of $checked containers failed"
		return 1
	fi

	log_success "Container health check: all $checked containers healthy"
	return 0
}

# T010: Check /healthz endpoint with timeout
check_healthz_endpoint() {
	log_info "Checking /healthz endpoint..."

	local http_code

	# Make request with timeout
	http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$HEALTHZ_TIMEOUT" "$HEALTHZ_URL" 2>/dev/null)
	local curl_exit=$?

	if [[ $curl_exit -ne 0 ]]; then
		if [[ $curl_exit -eq 28 ]]; then
			log_error "Healthz endpoint timed out after ${HEALTHZ_TIMEOUT}s"
		else
			log_error "Healthz endpoint unreachable (curl exit: $curl_exit)"
		fi
		return 1
	fi

	if [[ "$http_code" == "200" ]]; then
		log_success "Healthz endpoint: OK (HTTP $http_code)"
		return 0
	else
		log_error "Healthz endpoint returned HTTP $http_code"
		return 1
	fi
}

# T011: Check worker replica count
check_worker_replicas() {
	log_info "Checking worker replicas..."

	# Get running worker containers using docker compose
	if ! docker compose ps --format json &>/dev/null; then
		log_error "Failed to query worker containers"
		return 1
	fi

	# Check health of each worker
	local healthy_workers=0
	local unhealthy_workers=0

	while IFS= read -r worker_name; do
		[[ -z "$worker_name" ]] && continue

		local health
		health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}running{{end}}' "$worker_name" 2>/dev/null)

		if [[ "$health" == "healthy" ]] || [[ "$health" == "running" ]]; then
			((healthy_workers++))
		else
			((unhealthy_workers++))
			log_warn "Worker $worker_name: $health"
		fi
	done < <(docker compose ps --format json 2>/dev/null | jq -r 'select(.Service == "n8n-worker") | .Name')

	log_info "Workers: $healthy_workers healthy, $unhealthy_workers unhealthy (expected: $EXPECTED_WORKERS)"

	if [[ $healthy_workers -eq 0 ]]; then
		log_error "No healthy workers running"
		return 1
	fi

	if [[ $healthy_workers -lt $EXPECTED_WORKERS ]]; then
		log_warn "Fewer workers than expected: $healthy_workers of $EXPECTED_WORKERS"
		return 1
	fi

	if [[ $unhealthy_workers -gt 0 ]]; then
		log_warn "Some workers are unhealthy"
		return 1
	fi

	log_success "All $healthy_workers workers healthy"
	return 0
}

# T014/T015: Check ngrok tunnel connectivity
check_ngrok_tunnel() {
	log_info "Checking ngrok tunnel..."

	# Check if ngrok API is reachable
	local http_code
	http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time "$NGROK_TIMEOUT" "${NGROK_API_URL}/tunnels" 2>/dev/null)
	local curl_exit=$?

	if [[ $curl_exit -ne 0 ]]; then
		if [[ $curl_exit -eq 28 ]]; then
			log_error "ngrok API timed out after ${NGROK_TIMEOUT}s"
		else
			log_error "ngrok API unreachable (curl exit: $curl_exit)"
		fi
		return 1
	fi

	if [[ "$http_code" != "200" ]]; then
		log_error "ngrok API returned HTTP $http_code"
		return 1
	fi

	# Check for active tunnels
	local tunnel_data
	tunnel_data=$(curl -sf --max-time "$NGROK_TIMEOUT" "${NGROK_API_URL}/tunnels" 2>/dev/null)

	local tunnel_count
	tunnel_count=$(echo "$tunnel_data" | jq -r '.tunnels | length' 2>/dev/null)

	if [[ -z "$tunnel_count" ]] || [[ "$tunnel_count" == "null" ]] || [[ "$tunnel_count" -eq 0 ]]; then
		log_error "No active ngrok tunnels found"
		return 1
	fi

	# Get tunnel URL for logging
	local tunnel_url
	tunnel_url=$(echo "$tunnel_data" | jq -r '.tunnels[0].public_url // "unknown"' 2>/dev/null)

	log_success "ngrok tunnel active: $tunnel_url ($tunnel_count tunnel(s))"
	return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	# Parse arguments
	case "${1:-}" in
	--help | -h)
		show_help
		exit 0
		;;
	esac

	log_info "=========================================="
	log_info "Starting health check"
	log_info "=========================================="

	OVERALL_STATUS=0

	# Check container health
	if ! check_container_health; then
		OVERALL_STATUS=1
	fi

	# Check healthz endpoint
	if ! check_healthz_endpoint; then
		OVERALL_STATUS=1
	fi

	# Check worker replicas
	if ! check_worker_replicas; then
		if [[ $OVERALL_STATUS -eq 0 ]]; then
			OVERALL_STATUS=2
		fi
	fi

	# Check ngrok tunnel
	if ! check_ngrok_tunnel; then
		if [[ $OVERALL_STATUS -eq 0 ]]; then
			OVERALL_STATUS=2
		fi
	fi

	log_info "=========================================="
	if [[ $OVERALL_STATUS -eq 0 ]]; then
		log_success "All health checks passed"
	elif [[ $OVERALL_STATUS -eq 2 ]]; then
		log_warn "Health check completed with warnings"
	else
		log_error "Health check failed"
	fi

	exit $OVERALL_STATUS
}

main "$@"
