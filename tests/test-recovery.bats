#!/usr/bin/env bats
# =============================================================================
# Tests for test-recovery.sh - Disaster Recovery Testing Script
# =============================================================================

load 'test_helper'

setup() {
	common_setup

	# Create sample backup files
	echo "-- PostgreSQL dump" | gzip >"$TEST_BACKUP_DIR/postgres/n8n_20250101_020000.sql.gz"
	echo -n "REDIS0011" >"$TEST_BACKUP_DIR/redis/dump_20250101_020000.rdb"
	echo "test data" | gzip >"$TEST_BACKUP_DIR/n8n/n8n_data_20250101_020000.tar.gz"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Script Validation Tests
# -----------------------------------------------------------------------------

@test "test-recovery: script exists and is executable" {
	assert [ -f "$SCRIPTS_DIR/test-recovery.sh" ]
	assert [ -x "$SCRIPTS_DIR/test-recovery.sh" ]
}

@test "test-recovery: script passes bash syntax check" {
	run bash -n "$SCRIPTS_DIR/test-recovery.sh"
	assert_success
}

@test "test-recovery: script has proper header" {
	run head -10 "$SCRIPTS_DIR/test-recovery.sh"
	assert_success
	assert_output --partial "test-recovery.sh"
	assert_output --partial "Description:"
}

# -----------------------------------------------------------------------------
# Help Function Tests
# -----------------------------------------------------------------------------

@test "test-recovery: --help displays usage information" {
	run "$SCRIPTS_DIR/test-recovery.sh" --help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "--postgres"
	assert_output --partial "--redis"
	assert_output --partial "--n8n"
	assert_output --partial "--full"
}

@test "test-recovery: -h displays usage information" {
	run "$SCRIPTS_DIR/test-recovery.sh" -h
	assert_success
	assert_output --partial "Usage:"
}

@test "test-recovery: no arguments shows help" {
	run "$SCRIPTS_DIR/test-recovery.sh"
	assert_success
	assert_output --partial "Usage:"
}

# -----------------------------------------------------------------------------
# List Mode Tests
# -----------------------------------------------------------------------------

@test "test-recovery: --list shows available backups" {
	run "$SCRIPTS_DIR/test-recovery.sh" --list
	assert_success
	assert_output --partial "Available backups"
	assert_output --partial "PostgreSQL backups"
	assert_output --partial "Redis backups"
	assert_output --partial "n8n data backups"
}

# -----------------------------------------------------------------------------
# Error Handling Tests
# -----------------------------------------------------------------------------

@test "test-recovery: unknown option shows error" {
	run "$SCRIPTS_DIR/test-recovery.sh" --invalid
	assert_failure
	assert_output --partial "Unknown option"
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "test-recovery: log_info function exists" {
	source_script_functions "test-recovery.sh"
	run log_info "test message"
	assert_success
	assert_output --partial "INFO"
	assert_output --partial "test message"
}

@test "test-recovery: log_error function exists" {
	source_script_functions "test-recovery.sh"
	run log_error "test error"
	assert_success
	assert_output --partial "ERROR"
	assert_output --partial "test error"
}

@test "test-recovery: log_success function exists" {
	source_script_functions "test-recovery.sh"
	run log_success "test success"
	assert_success
	assert_output --partial "SUCCESS"
	assert_output --partial "test success"
}

@test "test-recovery: log_warn function exists" {
	source_script_functions "test-recovery.sh"
	run log_warn "test warning"
	assert_success
	assert_output --partial "WARN"
	assert_output --partial "test warning"
}

# -----------------------------------------------------------------------------
# Backup Finding Tests
# -----------------------------------------------------------------------------

@test "test-recovery: find_latest_backup postgres works with existing backups" {
	source_script_functions "test-recovery.sh"

	# Override BACKUP_DIR to test directory
	export BACKUP_DIR="$TEST_BACKUP_DIR"

	run find_latest_backup "postgres"
	assert_success
	assert_output --partial ".sql.gz"
}

@test "test-recovery: find_latest_backup redis works with existing backups" {
	source_script_functions "test-recovery.sh"

	# Override BACKUP_DIR to test directory
	export BACKUP_DIR="$TEST_BACKUP_DIR"

	run find_latest_backup "redis"
	assert_success
	assert_output --partial ".rdb"
}

@test "test-recovery: find_latest_backup n8n works with existing backups" {
	source_script_functions "test-recovery.sh"

	# Override BACKUP_DIR to test directory
	export BACKUP_DIR="$TEST_BACKUP_DIR"

	run find_latest_backup "n8n"
	assert_success
	assert_output --partial ".tar.gz"
}

@test "test-recovery: find_latest_backup fails for unknown type" {
	source_script_functions "test-recovery.sh"

	# Override BACKUP_DIR to test directory
	export BACKUP_DIR="$TEST_BACKUP_DIR"

	run find_latest_backup "unknown"
	assert_failure
	assert_output --partial "Unknown backup type"
}

@test "test-recovery: find_latest_backup fails with empty backup directory" {
	source_script_functions "test-recovery.sh"

	# Create empty backup directory
	local empty_backup_dir="$TEST_TEMP_DIR/empty_backups"
	mkdir -p "$empty_backup_dir/postgres"
	export BACKUP_DIR="$empty_backup_dir"

	run find_latest_backup "postgres"
	assert_failure
	assert_output --partial "No backup files found"
}

# -----------------------------------------------------------------------------
# Test Environment Tests
# -----------------------------------------------------------------------------

@test "test-recovery: setup_test_env creates test directory" {
	source_script_functions "test-recovery.sh"

	export TEST_DIR="$TEST_TEMP_DIR/recovery-test"

	run setup_test_env
	assert_success
	assert [ -d "$TEST_DIR" ]
}

@test "test-recovery: cleanup_test_env removes test directory" {
	source_script_functions "test-recovery.sh"

	export TEST_DIR="$TEST_TEMP_DIR/recovery-test"
	mkdir -p "$TEST_DIR"

	run cleanup_test_env
	assert_success
	assert [ ! -d "$TEST_DIR" ]
}

# -----------------------------------------------------------------------------
# Exit Code Tests
# -----------------------------------------------------------------------------

@test "test-recovery: defines correct exit codes in help" {
	run "$SCRIPTS_DIR/test-recovery.sh" --help
	assert_success
	assert_output --partial "Exit Codes:"
	assert_output --partial "0"
	assert_output --partial "1"
	assert_output --partial "2"
}
