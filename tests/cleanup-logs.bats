#!/usr/bin/env bats
# =============================================================================
# Tests for cleanup-logs.sh - Docker Container Log Cleanup Utility
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/cleanup-logs.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/cleanup-logs.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "cleanup-logs: log_info outputs with prefix" {
	source_script_functions "cleanup-logs.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[cleanup-logs]"
}

@test "cleanup-logs: log_error outputs with prefix" {
	source_script_functions "cleanup-logs.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[cleanup-logs]"
}

@test "cleanup-logs: log_success outputs with prefix" {
	source_script_functions "cleanup-logs.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
	assert_output --partial "[cleanup-logs]"
}

@test "cleanup-logs: log_warn outputs with prefix" {
	source_script_functions "cleanup-logs.sh"
	run log_warn "Warning message"
	assert_success
	assert_output --partial "[WARN]"
	assert_output --partial "[cleanup-logs]"
}

@test "cleanup-logs: show_help displays usage" {
	source_script_functions "cleanup-logs.sh"
	run show_help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "--dry-run"
	assert_output --partial "--force"
}

@test "cleanup-logs: human_size converts bytes to KB" {
	source_script_functions "cleanup-logs.sh"
	run human_size 2048
	assert_success
	assert_output "2.00K"
}

@test "cleanup-logs: human_size converts bytes to MB" {
	source_script_functions "cleanup-logs.sh"
	run human_size 2097152
	assert_success
	assert_output "2.00M"
}

@test "cleanup-logs: human_size converts bytes to GB" {
	source_script_functions "cleanup-logs.sh"
	run human_size 2147483648
	assert_success
	assert_output "2.00G"
}

@test "cleanup-logs: human_size handles small values" {
	source_script_functions "cleanup-logs.sh"
	run human_size 100
	assert_success
	assert_output "100B"
}

@test "cleanup-logs: get_log_path returns correct path format" {
	source_script_functions "cleanup-logs.sh"
	run get_log_path "abc123def456"
	assert_success
	assert_output "/var/lib/docker/containers/abc123def456/abc123def456-json.log"
}

@test "cleanup-logs: check_docker verifies docker availability" {
	source_script_functions "cleanup-logs.sh"
	run check_docker
	assert_success
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "cleanup-logs: default mode is dry-run" {
	source_script_functions "cleanup-logs.sh"
	assert_equal "$DRY_RUN" "true"
}

@test "cleanup-logs: default force is false" {
	source_script_functions "cleanup-logs.sh"
	assert_equal "$FORCE" "false"
}

@test "cleanup-logs: container prefix is n8n-" {
	source_script_functions "cleanup-logs.sh"
	assert_equal "$CONTAINER_PREFIX" "n8n-"
}

# -----------------------------------------------------------------------------
# Argument Parsing Tests
# -----------------------------------------------------------------------------

@test "cleanup-logs: supports --dry-run flag" {
	run grep -q "\-\-dry-run" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: supports --force flag" {
	run grep -q "\-\-force" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: supports --help flag" {
	run grep -q "\-\-help\|\-h" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: handles unknown options" {
	run grep -q "Unknown option" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Docker Integration Tests
# -----------------------------------------------------------------------------

@test "cleanup-logs: uses docker ps to list containers" {
	run grep -q "docker ps" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: uses truncate for log cleanup" {
	run grep -q "truncate" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: filters by container prefix" {
	run grep -q "CONTAINER_PREFIX" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: checks for root/sudo when force mode" {
	run grep -q "EUID" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Size Calculation Tests
# -----------------------------------------------------------------------------

@test "cleanup-logs: uses stat for file size" {
	run grep -q "stat" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: calculates total bytes" {
	run grep -q "total_bytes" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "cleanup-logs: script is executable" {
	assert [ -x "$SCRIPTS_DIR/cleanup-logs.sh" ]
}

@test "cleanup-logs: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: uses set -o pipefail" {
	run grep -q "set -o pipefail" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}

@test "cleanup-logs: has standard script header" {
	run head -10 "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_output --partial "cleanup-logs.sh"
	assert_output --partial "Description:"
}

@test "cleanup-logs: follows project exit code convention" {
	run grep -q "Exit Codes:" "$SCRIPTS_DIR/cleanup-logs.sh"
	assert_success
}
