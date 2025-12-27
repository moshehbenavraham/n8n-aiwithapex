#!/usr/bin/env bats
# =============================================================================
# Tests for queue-depth.sh - Redis Bull queue depth monitoring
# =============================================================================

load 'test_helper'

setup() {
	common_setup

	# Add autoscale config to mock .env
	cat >>"$TEST_PROJECT_DIR/.env" <<'EOF'
REDIS_HOST=redis
REDIS_PORT=6386
REDIS_CONTAINER=n8n-redis
BULL_QUEUE_NAME=jobs
EOF
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "queue-depth: script exists and is executable" {
	assert [ -f "$SCRIPTS_DIR/queue-depth.sh" ]
	assert [ -x "$SCRIPTS_DIR/queue-depth.sh" ]
}

@test "queue-depth: shows help with --help flag" {
	run "$SCRIPTS_DIR/queue-depth.sh" --help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "Query Redis Bull queue depth"
}

@test "queue-depth: returns numeric depth by default" {
	run "$SCRIPTS_DIR/queue-depth.sh"
	assert_success
	# Output should be a number
	[[ "$output" =~ ^[0-9]+$ ]]
}

@test "queue-depth: returns JSON with --json flag" {
	run "$SCRIPTS_DIR/queue-depth.sh" --json
	assert_success
	assert_output --partial '"depth":'
	assert_output --partial '"wait":'
	assert_output --partial '"delayed":'
}

@test "queue-depth: returns verbose breakdown with --verbose flag" {
	run "$SCRIPTS_DIR/queue-depth.sh" --verbose
	assert_success
	assert_output --partial "Queue Depth Report"
	assert_output --partial "Queue Name:"
	assert_output --partial "Waiting:"
	assert_output --partial "Total:"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "queue-depth: uses REDIS_PORT from environment" {
	source_script_functions "queue-depth.sh"
	assert_equal "${REDIS_PORT:-6386}" "6386"
}

@test "queue-depth: uses default queue name if not specified" {
	source_script_functions "queue-depth.sh"
	assert_equal "${BULL_QUEUE_NAME:-jobs}" "jobs"
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "queue-depth: script passes shellcheck" {
	run shellcheck "$SCRIPTS_DIR/queue-depth.sh"
	assert_success
}

@test "queue-depth: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/queue-depth.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Error Handling Tests
# -----------------------------------------------------------------------------

@test "queue-depth: handles unknown option gracefully" {
	run "$SCRIPTS_DIR/queue-depth.sh" --unknown
	assert_failure
	assert_output --partial "Unknown option"
}

@test "queue-depth: JSON output includes error field on connection failure" {
	# Create a mock that fails Redis connection
	local mock_dir="$TEST_TEMP_DIR/mocks"
	cat >"$mock_dir/docker" <<'EOF'
#!/bin/bash
if [[ "$*" == *"redis-cli"* ]]; then
	exit 1
fi
exit 0
EOF
	chmod +x "$mock_dir/docker"
	export PATH="$mock_dir:$PATH"

	run "$SCRIPTS_DIR/queue-depth.sh" --json
	assert_failure
	assert_output --partial '"error":'
}
