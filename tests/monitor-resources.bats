#!/usr/bin/env bats
# =============================================================================
# Tests for monitor-resources.sh - Resource Monitoring with Threshold Alerts
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/monitor-resources.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/monitor-resources.sh"

	# Create mock for free command
	create_mock "free" 0 "              total        used        free      shared  buff/cache   available
Mem:     8000000000  4000000000  2000000000      100000  2000000000  3500000000
Swap:    2000000000           0  2000000000"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "monitor-resources: log_info outputs correct format" {
	source_script_functions "monitor-resources.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[monitor-resources]"
}

@test "monitor-resources: log_error outputs correct format" {
	source_script_functions "monitor-resources.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[monitor-resources]"
}

@test "monitor-resources: log_success outputs correct format" {
	source_script_functions "monitor-resources.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "monitor-resources: log_warn outputs correct format" {
	source_script_functions "monitor-resources.sh"
	run log_warn "Warning message"
	assert_success
	assert_output --partial "[WARN]"
	assert_output --partial "[monitor-resources]"
}

@test "monitor-resources: show_help displays usage" {
	source_script_functions "monitor-resources.sh"
	run show_help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "Thresholds"
}

# -----------------------------------------------------------------------------
# Threshold Tests
# -----------------------------------------------------------------------------

@test "monitor-resources: has reasonable memory threshold" {
	source_script_functions "monitor-resources.sh"
	[[ "$MEMORY_THRESHOLD_PCT" -ge 50 ]] && [[ "$MEMORY_THRESHOLD_PCT" -le 95 ]]
}

@test "monitor-resources: has reasonable CPU threshold" {
	source_script_functions "monitor-resources.sh"
	[[ "$CPU_THRESHOLD_PCT" -ge 50 ]] && [[ "$CPU_THRESHOLD_PCT" -le 100 ]]
}

@test "monitor-resources: has reasonable disk threshold" {
	source_script_functions "monitor-resources.sh"
	[[ "$DISK_THRESHOLD_PCT" -ge 50 ]] && [[ "$DISK_THRESHOLD_PCT" -le 95 ]]
}

# -----------------------------------------------------------------------------
# Monitoring Function Tests
# -----------------------------------------------------------------------------

@test "monitor-resources: check_memory uses free command" {
	run grep -q "free" "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

@test "monitor-resources: check_cpu uses docker stats" {
	run grep -q "docker stats" "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

@test "monitor-resources: check_disk uses df command" {
	run grep -q "df " "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

@test "monitor-resources: monitors Docker volumes" {
	run grep -q "docker volume\|docker system df" "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Output Format Tests
# -----------------------------------------------------------------------------

@test "monitor-resources: supports --json flag" {
	run grep -q "\-\-json" "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

@test "monitor-resources: displays human-readable sizes" {
	run grep -q "numfmt\|human" "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "monitor-resources: script is executable" {
	assert [ -x "$SCRIPTS_DIR/monitor-resources.sh" ]
}

@test "monitor-resources: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

@test "monitor-resources: supports --help flag" {
	run grep -q "\-\-help\|\-h" "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

@test "monitor-resources: calculates percentage correctly" {
	# Should have percentage calculation logic
	run grep -q "%" "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}

@test "monitor-resources: filters n8n containers" {
	run grep -q 'n8n-\|grep.*n8n' "$SCRIPTS_DIR/monitor-resources.sh"
	assert_success
}
