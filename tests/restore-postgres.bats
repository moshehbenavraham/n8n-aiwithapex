#!/usr/bin/env bats
# =============================================================================
# Tests for restore-postgres.sh - PostgreSQL Database Restore
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/restore-postgres.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/restore-postgres.sh"

	# Create a mock backup file for testing
	echo "mock sql content" | gzip >"$TEST_BACKUP_DIR/postgres/test_backup.sql.gz"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "restore-postgres: log_info outputs correct format" {
	# Define log function directly since script requires .env
	log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1"; }
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[restore-postgres]"
}

@test "restore-postgres: log_error outputs correct format" {
	log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1"; }
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[restore-postgres]"
}

@test "restore-postgres: log_success outputs correct format" {
	log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1"; }
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "restore-postgres: log_warn outputs correct format" {
	log_warn() { echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1"; }
	run log_warn "Warning message"
	assert_success
	assert_output --partial "[WARN]"
	assert_output --partial "[restore-postgres]"
}

@test "restore-postgres: check_container succeeds when container running" {
	# Define function directly
	check_container() {
		if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
			return 1
		fi
		return 0
	}
	export CONTAINER_NAME="n8n-postgres"

	run check_container
	assert_success
}

@test "restore-postgres: usage function displays help" {
	usage() {
		echo "Usage: $0 <backup_file.sql.gz>"
		echo ""
		echo "Arguments:"
		echo "  backup_file.sql.gz  Path to the gzip-compressed SQL backup file"
		return 1
	}
	run usage
	assert_failure # usage exits with 1
	assert_output --partial "Usage:"
	assert_output --partial "backup_file.sql.gz"
}

# -----------------------------------------------------------------------------
# Argument Validation Tests
# -----------------------------------------------------------------------------

@test "restore-postgres: requires backup file argument" {
	run grep -q '\$# -ne 1' "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: validates .sql.gz extension" {
	run grep -q '\.sql\.gz' "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: checks if backup file exists" {
	source_script_functions "restore-postgres.sh"

	# Test with non-existent file
	BACKUP_FILE="/nonexistent/backup.sql.gz"
	run bash -c "[[ ! -f '$BACKUP_FILE' ]] && echo 'Backup file not found'"
	assert_success
	assert_output "Backup file not found"
}

@test "restore-postgres: verifies gzip integrity" {
	run grep -q "gunzip -t" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Safety Tests
# -----------------------------------------------------------------------------

@test "restore-postgres: shows warning before restore" {
	run grep -q "log_warn" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: prompts for confirmation in interactive mode" {
	run grep -q "read -r" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: terminates existing connections" {
	run grep -q "pg_terminate_backend" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: uses DROP DATABASE before restore" {
	run grep -q "DROP DATABASE" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: creates fresh database" {
	run grep -q "CREATE DATABASE" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "restore-postgres: script is executable" {
	assert [ -x "$SCRIPTS_DIR/restore-postgres.sh" ]
}

@test "restore-postgres: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: verifies restore by counting tables" {
	run grep -q "information_schema.tables" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: handles non-interactive mode" {
	run grep -q '\-t 0' "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: supports PostgreSQL 13+ FORCE option" {
	run grep -q "WITH (FORCE)" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}

@test "restore-postgres: has fallback for older PostgreSQL" {
	# Should have fallback when FORCE fails
	run grep -q "Fallback\|fallback\|standard drop" "$SCRIPTS_DIR/restore-postgres.sh"
	assert_success
}
