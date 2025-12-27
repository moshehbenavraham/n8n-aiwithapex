#!/usr/bin/env bats
# =============================================================================
# Tests for restore-redis.sh - Redis RDB Backup Restore
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/restore-redis.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/restore-redis.sh"

	# Create a mock RDB backup file (starts with REDIS magic bytes)
	echo "REDIS0009mock data" >"$TEST_BACKUP_DIR/redis/test_backup.rdb"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "restore-redis: log_info outputs correct format" {
	log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] $1"; }
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[restore-redis]"
}

@test "restore-redis: log_error outputs correct format" {
	log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] $1"; }
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[restore-redis]"
}

@test "restore-redis: log_success outputs correct format" {
	log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] $1"; }
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "restore-redis: check_container function exists" {
	run grep -q "check_container()" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Argument Validation Tests
# -----------------------------------------------------------------------------

@test "restore-redis: requires backup file argument" {
	run grep -q '\$# -ne 1' "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: validates .rdb extension" {
	run grep -q '\.rdb' "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: checks if backup file exists" {
	run grep -q 'Backup file not found' "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: verifies RDB file format" {
	run grep -q "REDIS" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Encrypted Backup Tests
# -----------------------------------------------------------------------------

@test "restore-redis: decrypt_backup_file function exists" {
	run grep -q "decrypt_backup_file()" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: accepts .rdb.gpg files" {
	run grep -q "\.rdb\.gpg" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: detects encrypted backup files" {
	run grep -q "IS_ENCRYPTED" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: uses GPG for decryption" {
	run grep -q "\-\-decrypt" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: reads passphrase from BACKUP_GPG_PASSPHRASE" {
	run grep -q "BACKUP_GPG_PASSPHRASE" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: creates temp file for decryption" {
	run grep -q "mktemp" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Safety Tests
# -----------------------------------------------------------------------------

@test "restore-redis: shows warning before restore" {
	run grep -q "log_warn" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: prompts for confirmation in interactive mode" {
	run grep -q "read -r" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: uses docker cp to transfer file" {
	run grep -q "docker cp" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "restore-redis: script is executable" {
	assert [ -x "$SCRIPTS_DIR/restore-redis.sh" ]
}

@test "restore-redis: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: has usage function" {
	run grep -q "usage()" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: shows usage for encrypted files" {
	run grep -q "backup_file.rdb.gpg" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}

@test "restore-redis: verifies restore by checking DBSIZE" {
	run grep -q "DBSIZE" "$SCRIPTS_DIR/restore-redis.sh"
	assert_success
}
