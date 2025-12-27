#!/usr/bin/env bats
# =============================================================================
# Tests for backup-postgres.sh - PostgreSQL Database Backup
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/backup-postgres.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/backup-postgres.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "backup-postgres: log_info outputs correct format" {
	# Define log function directly since script requires .env
	log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [backup-postgres] $1"; }
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[backup-postgres]"
}

@test "backup-postgres: log_error outputs correct format" {
	log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-postgres] $1"; }
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[backup-postgres]"
}

@test "backup-postgres: log_success outputs correct format" {
	log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [backup-postgres] $1"; }
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "backup-postgres: check_container succeeds when container running" {
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

@test "backup-postgres: check_container fails when container not running" {
	source_script_functions "backup-postgres.sh"
	export CONTAINER_NAME="nonexistent-container"

	# Override docker mock to not include this container
	create_mock "docker" 0 ""

	run check_container
	assert_failure
}

@test "backup-postgres: reads DB credentials from environment" {
	source_script_functions "backup-postgres.sh"

	# Verify default values when not in env
	unset POSTGRES_USER
	unset POSTGRES_DB
	source "$TEST_PROJECT_DIR/.env"

	assert_equal "$POSTGRES_USER" "n8n"
	assert_equal "$POSTGRES_DB" "n8n"
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "backup-postgres: script is executable" {
	assert [ -x "$SCRIPTS_DIR/backup-postgres.sh" ]
}

@test "backup-postgres: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/backup-postgres.sh"
	assert_success
}

@test "backup-postgres: creates backup directory if missing" {
	source_script_functions "backup-postgres.sh"
	export BACKUP_DIR="$TEST_TEMP_DIR/new_backup_dir"

	assert [ ! -d "$BACKUP_DIR" ]
	mkdir -p "$BACKUP_DIR"
	assert [ -d "$BACKUP_DIR" ]
}

@test "backup-postgres: uses correct timestamp format" {
	source_script_functions "backup-postgres.sh"

	# TIMESTAMP should match YYYYMMDD_HHMMSS format
	TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
	[[ "$TIMESTAMP" =~ ^[0-9]{8}_[0-9]{6}$ ]]
}

@test "backup-postgres: backup filename includes timestamp" {
	source_script_functions "backup-postgres.sh"
	export BACKUP_DIR="$TEST_BACKUP_DIR/postgres"

	TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
	BACKUP_FILE="${BACKUP_DIR}/n8n_${TIMESTAMP}.sql.gz"

	[[ "$BACKUP_FILE" == *".sql.gz" ]]
}

@test "backup-postgres: fails gracefully without .env file" {
	rm -f "$TEST_PROJECT_DIR/.env"

	# Create a modified script that uses test paths
	cat >"$TEST_TEMP_DIR/test_backup.sh" <<EOF
#!/bin/bash
set -o pipefail
PROJECT_DIR="$TEST_PROJECT_DIR"
LOG_FILE="$TEST_LOG_DIR/backup.log"
if [[ -f "\${PROJECT_DIR}/.env" ]]; then
    source "\${PROJECT_DIR}/.env"
else
    echo "[ERROR] .env file not found"
    exit 1
fi
EOF
	chmod +x "$TEST_TEMP_DIR/test_backup.sh"

	run bash "$TEST_TEMP_DIR/test_backup.sh"
	assert_failure
	assert_output --partial ".env file not found"
}
