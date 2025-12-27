#!/bin/bash
# ==============================================================================
# PostgreSQL Benchmark Script
# ==============================================================================
# Purpose: Run pgbench to measure PostgreSQL performance before/after tuning
# Usage: ./scripts/postgres-benchmark.sh [baseline|tuned|compare]
# Created: 2025-12-26
# Session: phase01-session03-postgresql-tuning
# ==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/data/benchmark"
BASELINE_FILE="$RESULTS_DIR/baseline.txt"
TUNED_FILE="$RESULTS_DIR/tuned.txt"

# pgbench parameters (conservative for WSL2)
SCALE_FACTOR=10
CLIENTS=5
THREADS=2
DURATION=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
	echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

ensure_results_dir() {
	if [[ ! -d "$RESULTS_DIR" ]]; then
		mkdir -p "$RESULTS_DIR"
		log_info "Created results directory: $RESULTS_DIR"
	fi
}

# ==============================================================================
# Benchmark Functions
# ==============================================================================

init_pgbench() {
	log_info "Initializing pgbench database (scale factor: $SCALE_FACTOR)..."
	docker compose exec -T postgres pgbench -i -s "$SCALE_FACTOR" -U n8n n8n 2>&1
	log_success "pgbench database initialized"
}

run_benchmark() {
	local label="$1"
	local output_file="$2"

	log_info "Running benchmark: $label"
	log_info "Parameters: clients=$CLIENTS, threads=$THREADS, duration=${DURATION}s"

	# Run pgbench and capture output
	local result
	result=$(docker compose exec -T postgres pgbench \
		-c "$CLIENTS" \
		-j "$THREADS" \
		-T "$DURATION" \
		-U n8n \
		n8n 2>&1)

	# Save full output
	echo "$result" >"$output_file"

	# Extract TPS (excluding connections)
	local tps
	tps=$(echo "$result" | grep "tps = " | tail -1 | sed 's/.*tps = \([0-9.]*\).*/\1/')

	if [[ -n "$tps" ]]; then
		log_success "Benchmark complete: $tps TPS"
		echo "$tps"
	else
		log_error "Failed to extract TPS from benchmark results"
		echo "0"
	fi
}

# ==============================================================================
# Commands
# ==============================================================================

cmd_baseline() {
	ensure_results_dir

	log_info "=== Running BASELINE benchmark ==="
	log_warn "This measures performance with DEFAULT PostgreSQL settings"

	# Check if pgbench is initialized
	local table_exists
	table_exists=$(docker compose exec -T postgres psql -U n8n -d n8n -tAc \
		"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'pgbench_accounts');" 2>/dev/null || echo "f")

	if [[ "$table_exists" != "t" ]]; then
		init_pgbench
	fi

	local tps
	tps=$(run_benchmark "baseline" "$BASELINE_FILE")

	echo ""
	log_success "=== BASELINE RESULTS ==="
	echo "TPS: $tps"
	echo "Results saved to: $BASELINE_FILE"
}

cmd_tuned() {
	ensure_results_dir

	log_info "=== Running TUNED benchmark ==="
	log_info "This measures performance with TUNED PostgreSQL settings"

	local tps
	tps=$(run_benchmark "tuned" "$TUNED_FILE")

	echo ""
	log_success "=== TUNED RESULTS ==="
	echo "TPS: $tps"
	echo "Results saved to: $TUNED_FILE"
}

cmd_compare() {
	if [[ ! -f "$BASELINE_FILE" ]]; then
		log_error "Baseline results not found. Run: $0 baseline"
		exit 1
	fi

	if [[ ! -f "$TUNED_FILE" ]]; then
		log_error "Tuned results not found. Run: $0 tuned"
		exit 1
	fi

	# Extract TPS values
	local baseline_tps tuned_tps
	baseline_tps=$(grep "tps = " "$BASELINE_FILE" | tail -1 | sed 's/.*tps = \([0-9.]*\).*/\1/')
	tuned_tps=$(grep "tps = " "$TUNED_FILE" | tail -1 | sed 's/.*tps = \([0-9.]*\).*/\1/')

	if [[ -z "$baseline_tps" ]] || [[ -z "$tuned_tps" ]]; then
		log_error "Could not extract TPS values from results"
		exit 1
	fi

	# Calculate improvement
	local improvement
	improvement=$(echo "scale=2; (($tuned_tps - $baseline_tps) / $baseline_tps) * 100" | bc)

	echo ""
	echo "=============================================="
	echo "  PostgreSQL Tuning Benchmark Results"
	echo "=============================================="
	echo ""
	printf "  %-20s %10s TPS\n" "Baseline:" "$baseline_tps"
	printf "  %-20s %10s TPS\n" "Tuned:" "$tuned_tps"
	echo "----------------------------------------------"
	printf "  %-20s %10s%%\n" "Improvement:" "$improvement"
	echo "=============================================="
	echo ""

	# Check against target
	local target=20
	if (($(echo "$improvement >= $target" | bc -l))); then
		log_success "Target met: ${improvement}% >= ${target}%"
	else
		log_warn "Target not met: ${improvement}% < ${target}%"
	fi
}

cmd_help() {
	echo "PostgreSQL Benchmark Script"
	echo ""
	echo "Usage: $0 <command>"
	echo ""
	echo "Commands:"
	echo "  baseline    Run benchmark with default PostgreSQL settings"
	echo "  tuned       Run benchmark with tuned PostgreSQL settings"
	echo "  compare     Compare baseline vs tuned results"
	echo "  init        Initialize pgbench database only"
	echo "  help        Show this help message"
	echo ""
	echo "Benchmark Parameters:"
	echo "  Scale Factor: $SCALE_FACTOR"
	echo "  Clients:      $CLIENTS"
	echo "  Threads:      $THREADS"
	echo "  Duration:     ${DURATION}s"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
	cd "$PROJECT_DIR"

	local command="${1:-help}"

	case "$command" in
	baseline)
		cmd_baseline
		;;
	tuned)
		cmd_tuned
		;;
	compare)
		cmd_compare
		;;
	init)
		ensure_results_dir
		init_pgbench
		;;
	help | --help | -h)
		cmd_help
		;;
	*)
		log_error "Unknown command: $command"
		cmd_help
		exit 1
		;;
	esac
}

main "$@"
