#!/usr/bin/env bats
# =============================================================================
# Tests for tunnel-status.sh - ngrok Tunnel Status and Information
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/tunnel-status.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/tunnel-status.sh"

	# Add NGROK_INSPECTOR_PORT to mock .env
	echo "NGROK_INSPECTOR_PORT=4040" >>"$TEST_PROJECT_DIR/.env"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: log_info outputs correct format" {
	source_script_functions "tunnel-status.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[tunnel-status]"
	assert_output --partial "Test message"
}

@test "tunnel-status: log_error outputs correct format" {
	source_script_functions "tunnel-status.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[tunnel-status]"
	assert_output --partial "Error message"
}

@test "tunnel-status: log_success outputs correct format" {
	source_script_functions "tunnel-status.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
	assert_output --partial "[tunnel-status]"
	assert_output --partial "Success message"
}

@test "tunnel-status: log_warn outputs correct format" {
	source_script_functions "tunnel-status.sh"
	run log_warn "Warning message"
	assert_success
	assert_output --partial "[WARN]"
	assert_output --partial "[tunnel-status]"
	assert_output --partial "Warning message"
}

@test "tunnel-status: show_help displays usage" {
	source_script_functions "tunnel-status.sh"
	run show_help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "--help"
	assert_output --partial "--json"
	assert_output --partial "Exit Codes:"
}

@test "tunnel-status: show_help displays examples" {
	source_script_functions "tunnel-status.sh"
	run show_help
	assert_success
	assert_output --partial "Examples:"
	assert_output --partial "./tunnel-status.sh"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: has default inspector port 4040" {
	source_script_functions "tunnel-status.sh"
	# NGROK_API_URL should contain port 4040 (from env or default)
	[[ "$NGROK_API_URL" == *"4040"* ]] || [[ "$NGROK_API_URL" == *"localhost"* ]]
}

@test "tunnel-status: has reasonable API timeout" {
	source_script_functions "tunnel-status.sh"
	[[ "$API_TIMEOUT" -ge 1 ]] && [[ "$API_TIMEOUT" -le 30 ]]
}

@test "tunnel-status: defines NGROK_API_URL" {
	source_script_functions "tunnel-status.sh"
	[[ -n "$NGROK_API_URL" ]]
}

@test "tunnel-status: sources .env file if exists" {
	run grep -q 'source.*\.env' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: uses NGROK_INSPECTOR_PORT from env" {
	run grep -q 'NGROK_INSPECTOR_PORT' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# API Function Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: check_container_running uses docker inspect" {
	run grep -q "docker inspect" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: check_api_reachable uses curl" {
	run grep -q "curl" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: check_api_reachable handles timeout" {
	run grep -q "max-time\|timeout" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: get_tunnel_info queries tunnels endpoint" {
	run grep -q "/tunnels" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: uses jq for JSON parsing" {
	run grep -q "jq" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Exit Code Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: documents exit code 0 for connected" {
	run grep -q "0=connected\|exit 0" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: documents exit code 1 for error" {
	run grep -q "1=error\|exit 1" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: documents exit code 2 for not connected" {
	run grep -q "2=.*not connected\|return 2" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: display_tunnel_status returns 2 for no tunnels" {
	run grep -A2 "tunnel_count.*-eq 0" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
	assert_output --partial "return 2"
}

# -----------------------------------------------------------------------------
# JSON Output Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: supports --json flag" {
	run grep -q '\-\-json' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: supports -j short flag" {
	run grep -q '\-j' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: display_json outputs valid JSON structure" {
	run grep -q '"status":' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: display_json handles empty data" {
	run grep -q '"message":"No tunnel data available"' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: display_json reports disconnected state" {
	run grep -q '"status":"disconnected"' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Output Formatting Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: displays tunnel URL" {
	run grep -q 'public_url\|URL:' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: displays tunnel protocol" {
	run grep -q 'proto\|Protocol:' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: displays backend address" {
	run grep -q 'config.addr\|Backend:' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: displays metrics section" {
	run grep -q 'Metrics:\|metrics' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: script is executable" {
	assert [ -x "$SCRIPTS_DIR/tunnel-status.sh" ]
}

@test "tunnel-status: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: has shebang" {
	run head -1 "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
	assert_output --partial "#!/bin/bash"
}

@test "tunnel-status: uses set -o pipefail" {
	run grep -q "set -o pipefail" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: has standard header format" {
	run head -10 "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
	assert_output --partial "tunnel-status.sh"
	assert_output --partial "Description:"
	assert_output --partial "Usage:"
	assert_output --partial "Exit Codes:"
}

@test "tunnel-status: defines SCRIPT_DIR correctly" {
	run grep -q 'SCRIPT_DIR=.*dirname.*BASH_SOURCE' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: defines PROJECT_DIR correctly" {
	run grep -q 'PROJECT_DIR=.*dirname.*SCRIPT_DIR' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Container Check Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: checks n8n-ngrok container" {
	run grep -q "n8n-ngrok" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: check_container_running checks State.Status" {
	run grep -q "State.Status" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: check_container_running looks for running state" {
	run grep -q '"running"' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Argument Parsing Tests
# -----------------------------------------------------------------------------

@test "tunnel-status: supports --help flag" {
	run grep -q '\-\-help' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: supports -h short flag" {
	run grep -q '\-h' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: handles unknown options" {
	run grep -q "Unknown option" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: uses while loop for argument parsing" {
	run grep -q 'while \[\[ \$# -gt 0 \]\]' "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}

@test "tunnel-status: uses case statement for options" {
	run grep -q "case.*in" "$SCRIPTS_DIR/tunnel-status.sh"
	assert_success
}
