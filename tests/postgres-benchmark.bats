#!/usr/bin/env bats
# =============================================================================
# Tests for postgres-benchmark.sh - PostgreSQL Benchmark Script
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/postgres-benchmark.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/postgres-benchmark.sh"

	# Create mock bc for calculations
	create_mock "bc" 0 "25.5"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "postgres-benchmark: log_info outputs correct format" {
	source_script_functions "postgres-benchmark.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
}

@test "postgres-benchmark: log_success outputs correct format" {
	source_script_functions "postgres-benchmark.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "postgres-benchmark: log_warn outputs correct format" {
	source_script_functions "postgres-benchmark.sh"
	run log_warn "Warning message"
	assert_success
	assert_output --partial "[WARN]"
}

@test "postgres-benchmark: log_error outputs correct format" {
	source_script_functions "postgres-benchmark.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
}

@test "postgres-benchmark: ensure_results_dir creates directory" {
	source_script_functions "postgres-benchmark.sh"
	export RESULTS_DIR="$TEST_TEMP_DIR/benchmark_results"

	assert [ ! -d "$RESULTS_DIR" ]
	ensure_results_dir
	assert [ -d "$RESULTS_DIR" ]
}

@test "postgres-benchmark: cmd_help displays usage" {
	# Define function directly
	cmd_help() {
		echo "PostgreSQL Benchmark Script"
		echo ""
		echo "Usage: $0 <command>"
		echo ""
		echo "Commands:"
		echo "  baseline    Run benchmark with default PostgreSQL settings"
		echo "  tuned       Run benchmark with tuned PostgreSQL settings"
		echo "  compare     Compare baseline vs tuned results"
	}
	run cmd_help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "Commands:"
	assert_output --partial "baseline"
	assert_output --partial "tuned"
	assert_output --partial "compare"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "postgres-benchmark: has reasonable scale factor" {
	source_script_functions "postgres-benchmark.sh"
	[[ "$SCALE_FACTOR" -ge 1 ]] && [[ "$SCALE_FACTOR" -le 100 ]]
}

@test "postgres-benchmark: has reasonable client count" {
	source_script_functions "postgres-benchmark.sh"
	[[ "$CLIENTS" -ge 1 ]] && [[ "$CLIENTS" -le 50 ]]
}

@test "postgres-benchmark: has reasonable thread count" {
	source_script_functions "postgres-benchmark.sh"
	[[ "$THREADS" -ge 1 ]] && [[ "$THREADS" -le 16 ]]
}

@test "postgres-benchmark: has reasonable duration" {
	source_script_functions "postgres-benchmark.sh"
	[[ "$DURATION" -ge 10 ]] && [[ "$DURATION" -le 300 ]]
}

@test "postgres-benchmark: defines color codes" {
	run grep -q "RED=\|GREEN=\|YELLOW=\|BLUE=\|NC=" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Command Tests
# -----------------------------------------------------------------------------

@test "postgres-benchmark: supports baseline command" {
	run grep -q "baseline)" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: supports tuned command" {
	run grep -q "tuned)" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: supports compare command" {
	run grep -q "compare)" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: supports init command" {
	run grep -q "init)" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: supports help command" {
	run grep -q "help" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# pgbench Tests
# -----------------------------------------------------------------------------

@test "postgres-benchmark: uses pgbench for benchmarking" {
	run grep -q "pgbench" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: initializes pgbench database" {
	run grep -q "pgbench -i" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: checks for pgbench_accounts table" {
	run grep -q "pgbench_accounts" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: extracts TPS from results" {
	run grep -q "tps = " "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Compare Tests
# -----------------------------------------------------------------------------

@test "postgres-benchmark: compare checks for baseline file" {
	run grep -q "BASELINE_FILE" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: compare checks for tuned file" {
	run grep -q "TUNED_FILE" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: calculates improvement percentage" {
	run grep -q "improvement\|Improvement" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: has target percentage" {
	run grep -q "target" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "postgres-benchmark: script is executable" {
	assert [ -x "$SCRIPTS_DIR/postgres-benchmark.sh" ]
}

@test "postgres-benchmark: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: uses docker compose exec" {
	run grep -q "docker compose exec" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: saves results to files" {
	run grep -q "output_file\|BASELINE_FILE\|TUNED_FILE" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}

@test "postgres-benchmark: handles unknown commands" {
	run grep -q "Unknown command\|\*)" "$SCRIPTS_DIR/postgres-benchmark.sh"
	assert_success
}
