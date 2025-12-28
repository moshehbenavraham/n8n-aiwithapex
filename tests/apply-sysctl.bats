#!/usr/bin/env bats
# =============================================================================
# Tests for apply-sysctl.sh - Sysctl Kernel Parameter Management
# =============================================================================

load 'test_helper'

setup() {
	common_setup

	# Create sysctl configuration file
	mkdir -p "$TEST_PROJECT_DIR/config"
	cat >"$TEST_PROJECT_DIR/config/99-n8n-optimizations.conf" <<'EOF'
# Test sysctl config
vm.overcommit_memory = 1
EOF
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Script Validation Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: script exists and is executable" {
	assert [ -f "$SCRIPTS_DIR/apply-sysctl.sh" ]
	assert [ -x "$SCRIPTS_DIR/apply-sysctl.sh" ]
}

@test "apply-sysctl: script passes bash syntax check" {
	run bash -n "$SCRIPTS_DIR/apply-sysctl.sh"
	assert_success
}

@test "apply-sysctl: script has proper header" {
	run head -10 "$SCRIPTS_DIR/apply-sysctl.sh"
	assert_success
	assert_output --partial "apply-sysctl.sh"
	assert_output --partial "Description:"
}

# -----------------------------------------------------------------------------
# Help Function Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: --help displays usage information" {
	run "$SCRIPTS_DIR/apply-sysctl.sh" --help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "--check"
	assert_output --partial "--verify"
	assert_output --partial "--apply"
}

@test "apply-sysctl: -h displays usage information" {
	run "$SCRIPTS_DIR/apply-sysctl.sh" -h
	assert_success
	assert_output --partial "Usage:"
}

# -----------------------------------------------------------------------------
# Check Mode Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: --check detects correct vm.overcommit_memory=1" {
	# Create sysctl mock that returns 1
	create_mock "sysctl" 0 "1"

	run "$SCRIPTS_DIR/apply-sysctl.sh" --check
	assert_success
	assert_output --partial "vm.overcommit_memory"
}

@test "apply-sysctl: --check detects incorrect vm.overcommit_memory=0" {
	# Create sysctl mock that returns 0
	create_mock "sysctl" 0 "0"

	run "$SCRIPTS_DIR/apply-sysctl.sh" --check
	assert_failure
	assert_output --partial "WARN"
}

@test "apply-sysctl: default mode is check" {
	# Create sysctl mock that returns 1
	create_mock "sysctl" 0 "1"

	run "$SCRIPTS_DIR/apply-sysctl.sh"
	assert_output --partial "Checking current sysctl settings"
}

# -----------------------------------------------------------------------------
# Apply Mode Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: --apply generates sudo commands" {
	run "$SCRIPTS_DIR/apply-sysctl.sh" --apply
	assert_success
	assert_output --partial "SUDO COMMANDS TO RUN"
	assert_output --partial "sudo cp"
	assert_output --partial "sudo chmod"
	assert_output --partial "sudo sysctl"
}

@test "apply-sysctl: --apply includes correct config path" {
	run "$SCRIPTS_DIR/apply-sysctl.sh" --apply
	assert_success
	assert_output --partial "99-n8n-optimizations.conf"
	assert_output --partial "/etc/sysctl.d/"
}

# -----------------------------------------------------------------------------
# Verify Mode Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: --verify detects missing system config" {
	run "$SCRIPTS_DIR/apply-sysctl.sh" --verify
	assert_failure
	assert_output --partial "Config not installed"
}

# -----------------------------------------------------------------------------
# Error Handling Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: unknown option shows error" {
	run "$SCRIPTS_DIR/apply-sysctl.sh" --invalid
	assert_failure
	assert_output --partial "Unknown option"
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: log_info function exists" {
	source_script_functions "apply-sysctl.sh"
	run log_info "test message"
	assert_success
	assert_output --partial "INFO"
	assert_output --partial "test message"
}

@test "apply-sysctl: log_error function exists" {
	source_script_functions "apply-sysctl.sh"
	run log_error "test error"
	assert_success
	assert_output --partial "ERROR"
	assert_output --partial "test error"
}

@test "apply-sysctl: log_success function exists" {
	source_script_functions "apply-sysctl.sh"
	run log_success "test success"
	assert_success
	assert_output --partial "SUCCESS"
	assert_output --partial "test success"
}

@test "apply-sysctl: log_warn function exists" {
	source_script_functions "apply-sysctl.sh"
	run log_warn "test warning"
	assert_success
	assert_output --partial "WARN"
	assert_output --partial "test warning"
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "apply-sysctl: REQUIRED_SETTINGS includes vm.overcommit_memory" {
	# Verify the script contains vm.overcommit_memory configuration
	run grep -q 'vm.overcommit_memory' "$SCRIPTS_DIR/apply-sysctl.sh"
	assert_success
}
