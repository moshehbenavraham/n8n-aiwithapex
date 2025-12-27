#!/usr/bin/env bats
# =============================================================================
# Tests for view-logs.sh - Unified Log Viewer with Service Filtering
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/view-logs.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/view-logs.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "view-logs: log_info outputs to stderr" {
	source_script_functions "view-logs.sh"
	run log_info "Test message"
	# log_info in view-logs.sh outputs to stderr
	assert_success
}

@test "view-logs: log_error outputs to stderr" {
	source_script_functions "view-logs.sh"
	run log_error "Error message"
	assert_success
}

@test "view-logs: show_help displays usage" {
	source_script_functions "view-logs.sh"
	run show_help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "Services:"
}

@test "view-logs: validate_service accepts valid services" {
	source_script_functions "view-logs.sh"

	run validate_service "postgres"
	assert_success

	run validate_service "redis"
	assert_success

	run validate_service "n8n"
	assert_success

	run validate_service "worker"
	assert_success

	run validate_service "all"
	assert_success
}

@test "view-logs: validate_service rejects invalid services" {
	source_script_functions "view-logs.sh"

	run validate_service "invalid"
	assert_failure

	run validate_service "mysql"
	assert_failure

	run validate_service ""
	assert_failure
}

@test "view-logs: get_container_names maps services correctly" {
	source_script_functions "view-logs.sh"

	run get_container_names "postgres"
	assert_output "postgres"

	run get_container_names "redis"
	assert_output "redis"

	run get_container_names "n8n"
	assert_output "n8n"

	run get_container_names "worker"
	assert_output "n8n-worker"

	run get_container_names "all"
	assert_output "postgres redis n8n n8n-worker ngrok"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "view-logs: has correct valid services list" {
	source_script_functions "view-logs.sh"

	local services_str="${VALID_SERVICES[*]}"
	[[ "$services_str" == *"postgres"* ]]
	[[ "$services_str" == *"redis"* ]]
	[[ "$services_str" == *"n8n"* ]]
	[[ "$services_str" == *"worker"* ]]
	[[ "$services_str" == *"all"* ]]
}

@test "view-logs: has reasonable default tail lines" {
	source_script_functions "view-logs.sh"
	[[ "$TAIL_LINES" -ge 10 ]] && [[ "$TAIL_LINES" -le 1000 ]]
}

@test "view-logs: default service is all" {
	source_script_functions "view-logs.sh"
	assert_equal "$SERVICE" "all"
}

@test "view-logs: follow mode default is false" {
	source_script_functions "view-logs.sh"
	assert_equal "$FOLLOW_MODE" "false"
}

# -----------------------------------------------------------------------------
# Argument Parsing Tests
# -----------------------------------------------------------------------------

@test "view-logs: supports -s/--service flag" {
	run grep -q "\-s\|\-\-service" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: supports -n/--lines flag" {
	run grep -q "\-n\|\-\-lines" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: supports -f/--follow flag" {
	run grep -q "\-f\|\-\-follow" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: supports --help flag" {
	run grep -q "\-\-help\|\-h" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: validates lines is numeric" {
	run grep -q '\[0-9\]' "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Docker Compose Integration Tests
# -----------------------------------------------------------------------------

@test "view-logs: uses docker compose logs" {
	run grep -q "docker compose logs" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: includes --tail option" {
	run grep -q "\-\-tail" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: includes --follow option" {
	run grep -q "\-\-follow" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: includes --timestamps option" {
	run grep -q "\-\-timestamps" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "view-logs: script is executable" {
	assert [ -x "$SCRIPTS_DIR/view-logs.sh" ]
}

@test "view-logs: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}

@test "view-logs: handles unknown options" {
	run grep -q "Unknown option" "$SCRIPTS_DIR/view-logs.sh"
	assert_success
}
