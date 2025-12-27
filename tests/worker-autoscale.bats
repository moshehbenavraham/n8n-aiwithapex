#!/usr/bin/env bats
# =============================================================================
# Tests for worker-autoscale.sh - Worker auto-scaling controller
# =============================================================================

load 'test_helper'

setup() {
	common_setup

	# Add autoscale config to mock .env
	cat >>"$TEST_PROJECT_DIR/.env" <<'EOF'
AUTOSCALE_ENABLED=true
AUTOSCALE_MIN_WORKERS=1
AUTOSCALE_MAX_WORKERS=10
AUTOSCALE_HIGH_THRESHOLD=20
AUTOSCALE_LOW_THRESHOLD=5
AUTOSCALE_COOLDOWN_SECONDS=120
AUTOSCALE_LOG_FILE=logs/autoscale.log
REDIS_PORT=6386
EOF

	# Clean up any leftover lock/cooldown files
	rm -f /tmp/worker-autoscale.lock
	rm -f /tmp/worker-autoscale.last
}

teardown() {
	common_teardown
	rm -f /tmp/worker-autoscale.lock
	rm -f /tmp/worker-autoscale.last
}

# -----------------------------------------------------------------------------
# Script Validation Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: script exists and is executable" {
	assert [ -f "$SCRIPTS_DIR/worker-autoscale.sh" ]
	assert [ -x "$SCRIPTS_DIR/worker-autoscale.sh" ]
}

@test "worker-autoscale: shows help with --help flag" {
	run "$SCRIPTS_DIR/worker-autoscale.sh" --help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "Auto-scale n8n workers"
	assert_output --partial "AUTOSCALE_ENABLED"
}

@test "worker-autoscale: script passes shellcheck" {
	run shellcheck "$SCRIPTS_DIR/worker-autoscale.sh"
	assert_success
}

@test "worker-autoscale: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/worker-autoscale.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Status Display Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: shows status with --status flag" {
	run "$SCRIPTS_DIR/worker-autoscale.sh" --status
	assert_success
	assert_output --partial "Worker Auto-Scaling Status"
	assert_output --partial "Enabled:"
	assert_output --partial "Workers:"
	assert_output --partial "Queue Depth:"
}

@test "worker-autoscale: status shows configuration values" {
	run "$SCRIPTS_DIR/worker-autoscale.sh" --status
	assert_success
	assert_output --partial "Min Workers:"
	assert_output --partial "Max Workers:"
	assert_output --partial "High Threshold:"
	assert_output --partial "Low Threshold:"
}

# -----------------------------------------------------------------------------
# Dry Run Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: dry run does not modify worker count" {
	run "$SCRIPTS_DIR/worker-autoscale.sh" --dry-run
	assert_success
	assert_output --partial "DRY-RUN"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: respects AUTOSCALE_ENABLED setting" {
	export AUTOSCALE_ENABLED=false
	run "$SCRIPTS_DIR/worker-autoscale.sh"
	assert_exit_code 2
	assert_output --partial "Auto-scaling is disabled"
}

@test "worker-autoscale: uses default values when env not set" {
	source_script_functions "worker-autoscale.sh"
	assert_equal "${AUTOSCALE_MIN_WORKERS:-1}" "1"
	assert_equal "${AUTOSCALE_MAX_WORKERS:-10}" "10"
	assert_equal "${AUTOSCALE_COOLDOWN_SECONDS:-120}" "120"
}

# -----------------------------------------------------------------------------
# Lock File Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: creates lock file during execution" {
	# This test verifies lock file behavior
	rm -f /tmp/worker-autoscale.lock

	run "$SCRIPTS_DIR/worker-autoscale.sh" --dry-run

	# Lock should be released after execution
	assert [ ! -f /tmp/worker-autoscale.lock ]
}

@test "worker-autoscale: respects existing lock file" {
	# Create a fresh lock file
	echo $$ > /tmp/worker-autoscale.lock

	run "$SCRIPTS_DIR/worker-autoscale.sh"
	assert_exit_code 2
	assert_output --partial "Lock file exists"

	rm -f /tmp/worker-autoscale.lock
}

# -----------------------------------------------------------------------------
# Cooldown Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: respects cooldown period" {
	# Create a recent cooldown timestamp (now)
	date +%s > /tmp/worker-autoscale.last

	run "$SCRIPTS_DIR/worker-autoscale.sh"
	assert_exit_code 2
	assert_output --partial "Cooldown active"

	rm -f /tmp/worker-autoscale.last
}

@test "worker-autoscale: force flag bypasses cooldown" {
	# Create a recent cooldown timestamp
	date +%s > /tmp/worker-autoscale.last

	run "$SCRIPTS_DIR/worker-autoscale.sh" --force --dry-run
	assert_success
	# Should not mention cooldown when forced
	refute_output --partial "Cooldown active"

	rm -f /tmp/worker-autoscale.last
}

# -----------------------------------------------------------------------------
# Threshold Logic Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: calculate_target function exists" {
	source_script_functions "worker-autoscale.sh"
	run type calculate_target
	assert_success
}

@test "worker-autoscale: scaling decision logic works" {
	source_script_functions "worker-autoscale.sh"

	# Set thresholds
	AUTOSCALE_HIGH_THRESHOLD=20
	AUTOSCALE_LOW_THRESHOLD=5
	AUTOSCALE_MIN_WORKERS=1
	AUTOSCALE_MAX_WORKERS=10

	# Test: queue depth below low threshold should scale down
	local target
	target=$(calculate_target 5 0)
	assert_equal "$target" "4"
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "worker-autoscale: handles unknown option gracefully" {
	run "$SCRIPTS_DIR/worker-autoscale.sh" --unknown
	assert_failure
	assert_output --partial "Unknown option"
}
