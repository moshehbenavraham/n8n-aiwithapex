#!/usr/bin/env bats
# =============================================================================
# Tests for tunnel-manage.sh - Unified ngrok Tunnel Management
# =============================================================================

load 'test_helper'

setup() {
	common_setup

	# Copy the script to test directory
	cp "$SCRIPTS_DIR/tunnel-manage.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/tunnel-manage.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests - Logging
# -----------------------------------------------------------------------------

@test "tunnel-manage: log_info outputs correct format" {
	source_script_functions "tunnel-manage.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[tunnel-manage]"
	assert_output --partial "Test message"
}

@test "tunnel-manage: log_error outputs correct format" {
	source_script_functions "tunnel-manage.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[tunnel-manage]"
	assert_output --partial "Error message"
}

@test "tunnel-manage: log_success outputs correct format" {
	source_script_functions "tunnel-manage.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
	assert_output --partial "[tunnel-manage]"
}

@test "tunnel-manage: log_warn outputs correct format" {
	source_script_functions "tunnel-manage.sh"
	run log_warn "Warning message"
	assert_success
	assert_output --partial "[WARN]"
	assert_output --partial "[tunnel-manage]"
}

# -----------------------------------------------------------------------------
# Function Tests - Container Checks
# -----------------------------------------------------------------------------

@test "tunnel-manage: check_ngrok_container returns success when running" {
	source_script_functions "tunnel-manage.sh"

	# Docker mock already returns "running" for inspect
	run check_ngrok_container
	assert_success
}

@test "tunnel-manage: check_ngrok_healthy returns success when healthy" {
	source_script_functions "tunnel-manage.sh"

	# Docker mock already returns "healthy" for health check
	run check_ngrok_healthy
	assert_success
}

@test "tunnel-manage: check_ngrok_api handles unreachable API" {
	source_script_functions "tunnel-manage.sh"

	# Create curl mock that returns non-200
	local mock_dir="$TEST_TEMP_DIR/mocks"
	cat >"$mock_dir/curl" <<'EOF'
#!/bin/bash
echo "000"
exit 1
EOF
	chmod +x "$mock_dir/curl"

	run check_ngrok_api
	assert_failure
}

# -----------------------------------------------------------------------------
# Argument Parsing Tests
# -----------------------------------------------------------------------------

@test "tunnel-manage: --help shows usage" {
	run bash "$SCRIPTS_DIR/tunnel-manage.sh" --help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "Commands:"
	assert_output --partial "start"
	assert_output --partial "stop"
	assert_output --partial "status"
	assert_output --partial "restart"
}

@test "tunnel-manage: -h shows usage" {
	run bash "$SCRIPTS_DIR/tunnel-manage.sh" -h
	assert_success
	assert_output --partial "Usage:"
}

@test "tunnel-manage: help command shows usage" {
	run bash "$SCRIPTS_DIR/tunnel-manage.sh" help
	assert_success
	assert_output --partial "Usage:"
}

@test "tunnel-manage: no command shows error" {
	run bash "$SCRIPTS_DIR/tunnel-manage.sh"
	assert_failure
	assert_output --partial "No command specified"
}

@test "tunnel-manage: unknown command shows error" {
	run bash "$SCRIPTS_DIR/tunnel-manage.sh" invalid
	assert_failure
	assert_output --partial "Unknown option or command"
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "tunnel-manage: script is executable" {
	assert [ -x "$SCRIPTS_DIR/tunnel-manage.sh" ]
}

@test "tunnel-manage: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/tunnel-manage.sh"
	assert_success
}

@test "tunnel-manage: shellcheck passes" {
	if ! command -v shellcheck &>/dev/null; then
		skip "shellcheck not installed"
	fi
	run shellcheck "$SCRIPTS_DIR/tunnel-manage.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "tunnel-manage: uses correct container name" {
	source_script_functions "tunnel-manage.sh"
	assert_equal "$NGROK_CONTAINER" "n8n-ngrok"
}

@test "tunnel-manage: uses correct service name" {
	source_script_functions "tunnel-manage.sh"
	assert_equal "$NGROK_SERVICE" "ngrok"
}

@test "tunnel-manage: uses correct default API port" {
	source_script_functions "tunnel-manage.sh"
	# NGROK_INSPECTOR_PORT is not set, so should use default 4040
	[[ "$NGROK_API_URL" == *"4040"* ]]
}

@test "tunnel-manage: API timeout is reasonable" {
	source_script_functions "tunnel-manage.sh"
	assert_equal "$API_TIMEOUT" "5"
}

# -----------------------------------------------------------------------------
# Behavior Tests
# -----------------------------------------------------------------------------

@test "tunnel-manage: show_help includes all commands" {
	source_script_functions "tunnel-manage.sh"
	run show_help
	assert_success
	assert_output --partial "start"
	assert_output --partial "stop"
	assert_output --partial "status"
	assert_output --partial "restart"
	assert_output --partial "help"
}

@test "tunnel-manage: show_help includes exit codes" {
	source_script_functions "tunnel-manage.sh"
	run show_help
	assert_success
	assert_output --partial "Exit Codes:"
	assert_output --partial "0"
	assert_output --partial "1"
	assert_output --partial "2"
}

@test "tunnel-manage: script uses docker compose not docker-compose" {
	run grep -c "docker compose" "$SCRIPTS_DIR/tunnel-manage.sh"
	assert_success
	# Should find multiple occurrences of "docker compose"
	[[ "$output" -ge 2 ]]
}

@test "tunnel-manage: script does not use deprecated docker-compose" {
	run grep -c "docker-compose" "$SCRIPTS_DIR/tunnel-manage.sh"
	# Should not find docker-compose (old format)
	assert_failure
}
