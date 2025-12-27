#!/bin/bash
# =============================================================================
# system-status.sh - Dashboard-Style System Status Report
# =============================================================================
# Description: Displays a comprehensive status dashboard for the n8n stack
#              including containers, resources, queue status, and endpoints.
# Usage: ./system-status.sh [--help] [--json]
# Exit Codes: 0=all healthy, 1=issues detected, 2=warning
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/system-status.log"

# Endpoints
HEALTHZ_URL="http://localhost:5678/healthz"
N8N_URL="http://localhost:5678"
METRICS_URL="http://localhost:5678/metrics"

# Redis settings (non-standard port) - used via docker exec to n8n-redis

# Output format (reserved for future JSON output support)
# shellcheck disable=SC2034
OUTPUT_JSON=false

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [system-status] $1" | tee -a "$LOG_FILE"
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Displays comprehensive n8n stack status dashboard:
  - Container status and health
  - Resource usage (memory, CPU, disk)
  - Queue status (pending jobs)
  - Endpoint availability

Options:
  --help, -h     Show this help message
  --json         Output results in JSON format

Exit Codes:
  0  All systems healthy
  1  One or more issues detected
  2  Warning (non-critical issues)

Examples:
  ./system-status.sh           # Display status dashboard
  ./system-status.sh --json    # JSON output for scripting
EOF
}

print_separator() {
	echo "=============================================="
}

print_section_header() {
	echo ""
	echo "--- $1 ---"
}

# T017: Container status section with health states
show_container_status() {
	print_section_header "CONTAINER STATUS"

	local has_issues=false

	# Get container status
	local containers
	containers=$(docker ps --format "{{.Names}}\t{{.Status}}" 2>/dev/null | grep "^n8n-" | sort)

	if [[ -z "$containers" ]]; then
		echo "  No n8n containers found"
		return 1
	fi

	printf "  %-25s %-15s %s\n" "CONTAINER" "STATE" "HEALTH"
	printf "  %-25s %-15s %s\n" "---------" "-----" "------"

	while IFS=$'\t' read -r name status; do
		[[ -z "$name" ]] && continue

		# Extract health from status (e.g., "Up 2 hours (healthy)")
		local health="N/A"

		if [[ "$status" == *"(healthy)"* ]]; then
			health="healthy"
		elif [[ "$status" == *"(unhealthy)"* ]]; then
			health="unhealthy"
			has_issues=true
		elif [[ "$status" == *"(starting)"* ]]; then
			health="starting"
		fi

		# Format uptime (strip health status in parentheses)
		local uptime="${status%% (*}"

		printf "  %-25s %-15s %s\n" "$name" "$uptime" "$health"
	done <<<"$containers"

	# Count workers
	local worker_count
	worker_count=$(echo "$containers" | grep -c "n8n-worker" || echo "0")
	echo ""
	echo "  Workers: $worker_count running"

	if [[ "$has_issues" == "true" ]]; then
		return 1
	fi
	return 0
}

# T018: Resource summary section
show_resource_summary() {
	print_section_header "RESOURCE USAGE"

	local has_warning=false

	# Memory usage
	local mem_info
	mem_info=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2 " (" int($3/$2*100) "%)"}')
	local mem_pct
	mem_pct=$(free 2>/dev/null | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')

	echo "  Memory:    $mem_info"
	if [[ $mem_pct -ge 80 ]]; then
		echo "             [WARNING: Above 80% threshold]"
		has_warning=true
	fi

	# Disk usage
	local disk_info
	disk_info=$(df -h "$PROJECT_DIR" 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
	local disk_pct
	disk_pct=$(df "$PROJECT_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')

	echo "  Disk:      $disk_info"
	if [[ $disk_pct -ge 85 ]]; then
		echo "             [WARNING: Above 85% threshold]"
		has_warning=true
	fi

	# CPU load average
	local load_avg
	load_avg=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs)
	echo "  Load Avg:  $load_avg"

	# Container resource totals
	echo ""
	echo "  Container Resources:"
	local stats
	stats=$(docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep "^n8n-")

	if [[ -n "$stats" ]]; then
		printf "    %-25s %-10s %s\n" "CONTAINER" "CPU" "MEMORY"
		printf "    %-25s %-10s %s\n" "---------" "---" "------"
		while IFS=$'\t' read -r name cpu mem; do
			printf "    %-25s %-10s %s\n" "$name" "$cpu" "$mem"
		done <<<"$stats"
	fi

	if [[ "$has_warning" == "true" ]]; then
		return 1
	fi
	return 0
}

# T019: Queue status section using redis-cli
show_queue_status() {
	print_section_header "QUEUE STATUS"

	# Try to get queue info from Redis via docker exec
	local redis_container="n8n-redis"

	# Check if redis container exists
	if ! docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${redis_container}$"; then
		echo "  Redis container not running"
		return 1
	fi

	# Get Bull queue keys from Redis
	local queue_keys
	queue_keys=$(docker exec "$redis_container" redis-cli -p 6386 KEYS "bull:*" 2>/dev/null | head -20)

	if [[ -z "$queue_keys" ]]; then
		echo "  No Bull queues found (or empty)"
		echo "  Queue system: Ready"
		return 0
	fi

	# Count queue items
	local waiting_count=0
	local active_count=0
	local completed_count=0
	local failed_count=0

	# Get waiting jobs count
	waiting_count=$(docker exec "$redis_container" redis-cli -p 6386 LLEN "bull:jobs:wait" 2>/dev/null || echo "0")
	[[ -z "$waiting_count" ]] && waiting_count=0

	# Get active jobs count
	active_count=$(docker exec "$redis_container" redis-cli -p 6386 LLEN "bull:jobs:active" 2>/dev/null || echo "0")
	[[ -z "$active_count" ]] && active_count=0

	# Get completed jobs count (from sorted set)
	completed_count=$(docker exec "$redis_container" redis-cli -p 6386 ZCARD "bull:jobs:completed" 2>/dev/null || echo "0")
	[[ -z "$completed_count" ]] && completed_count=0

	# Get failed jobs count
	failed_count=$(docker exec "$redis_container" redis-cli -p 6386 ZCARD "bull:jobs:failed" 2>/dev/null || echo "0")
	[[ -z "$failed_count" ]] && failed_count=0

	echo "  Queue Statistics:"
	printf "    %-15s %s\n" "Waiting:" "$waiting_count"
	printf "    %-15s %s\n" "Active:" "$active_count"
	printf "    %-15s %s\n" "Completed:" "$completed_count"
	printf "    %-15s %s\n" "Failed:" "$failed_count"

	# Check Redis memory usage
	local redis_mem
	redis_mem=$(docker exec "$redis_container" redis-cli -p 6386 INFO memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
	if [[ -n "$redis_mem" ]]; then
		echo ""
		echo "  Redis Memory: $redis_mem"
	fi

	if [[ $failed_count -gt 0 ]]; then
		echo ""
		echo "  [WARNING: $failed_count failed jobs in queue]"
		return 1
	fi

	return 0
}

# T020: Endpoint status section
show_endpoint_status() {
	print_section_header "ENDPOINT STATUS"

	local has_issues=false

	printf "  %-30s %-10s %s\n" "ENDPOINT" "STATUS" "RESPONSE"
	printf "  %-30s %-10s %s\n" "--------" "------" "--------"

	# Check healthz endpoint
	local healthz_code
	healthz_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$HEALTHZ_URL" 2>/dev/null)
	if [[ "$healthz_code" == "200" ]]; then
		printf "  %-30s %-10s %s\n" "/healthz" "OK" "HTTP $healthz_code"
	else
		printf "  %-30s %-10s %s\n" "/healthz" "FAIL" "HTTP $healthz_code"
		has_issues=true
	fi

	# Check n8n web interface
	local n8n_code
	n8n_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$N8N_URL" 2>/dev/null)
	if [[ "$n8n_code" == "200" ]] || [[ "$n8n_code" == "302" ]]; then
		printf "  %-30s %-10s %s\n" "n8n Web UI" "OK" "HTTP $n8n_code"
	else
		printf "  %-30s %-10s %s\n" "n8n Web UI" "FAIL" "HTTP $n8n_code"
		has_issues=true
	fi

	# Check metrics endpoint
	local metrics_code
	metrics_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$METRICS_URL" 2>/dev/null)
	if [[ "$metrics_code" == "200" ]]; then
		printf "  %-30s %-10s %s\n" "/metrics (Prometheus)" "OK" "HTTP $metrics_code"
	else
		printf "  %-30s %-10s %s\n" "/metrics (Prometheus)" "FAIL" "HTTP $metrics_code"
		# Metrics failure is not critical
	fi

	# Check PostgreSQL connection via n8n
	if docker exec n8n-postgres pg_isready -U n8n &>/dev/null; then
		printf "  %-30s %-10s %s\n" "PostgreSQL" "OK" "accepting connections"
	else
		printf "  %-30s %-10s %s\n" "PostgreSQL" "FAIL" "not ready"
		has_issues=true
	fi

	# Check Redis connection
	local redis_ping
	redis_ping=$(docker exec n8n-redis redis-cli -p 6386 PING 2>/dev/null)
	if [[ "$redis_ping" == "PONG" ]]; then
		printf "  %-30s %-10s %s\n" "Redis" "OK" "PONG"
	else
		printf "  %-30s %-10s %s\n" "Redis" "FAIL" "no response"
		has_issues=true
	fi

	if [[ "$has_issues" == "true" ]]; then
		return 1
	fi
	return 0
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
		--json)
			# shellcheck disable=SC2034
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

	OVERALL_STATUS=0

	print_separator
	echo "  N8N STACK STATUS DASHBOARD"
	echo "  $(date '+%Y-%m-%d %H:%M:%S')"
	print_separator

	# Show container status
	if ! show_container_status; then
		OVERALL_STATUS=1
	fi

	# Show resource summary
	if ! show_resource_summary; then
		if [[ $OVERALL_STATUS -eq 0 ]]; then
			OVERALL_STATUS=2
		fi
	fi

	# Show queue status
	if ! show_queue_status; then
		if [[ $OVERALL_STATUS -eq 0 ]]; then
			OVERALL_STATUS=2
		fi
	fi

	# Show endpoint status
	if ! show_endpoint_status; then
		OVERALL_STATUS=1
	fi

	print_separator
	if [[ $OVERALL_STATUS -eq 0 ]]; then
		echo "  STATUS: ALL SYSTEMS HEALTHY"
	elif [[ $OVERALL_STATUS -eq 2 ]]; then
		echo "  STATUS: WARNINGS DETECTED"
	else
		echo "  STATUS: ISSUES DETECTED"
	fi
	print_separator

	exit $OVERALL_STATUS
}

main "$@"
