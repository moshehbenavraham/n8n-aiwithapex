#!/usr/bin/env bats
# =============================================================================
# Tests for restore-n8n.sh - n8n Data Volume Restore
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/restore-n8n.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/restore-n8n.sh"

	# Create a mock tar.gz backup file
	mkdir -p "$TEST_TEMP_DIR/mock_data"
	echo "mock n8n data" >"$TEST_TEMP_DIR/mock_data/test.txt"
	tar czf "$TEST_BACKUP_DIR/n8n/test_backup.tar.gz" -C "$TEST_TEMP_DIR/mock_data" .
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "restore-n8n: log_info outputs correct format" {
	log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] $1"; }
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[restore-n8n]"
}

@test "restore-n8n: log_error outputs correct format" {
	log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] $1"; }
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[restore-n8n]"
}

@test "restore-n8n: log_success outputs correct format" {
	log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] $1"; }
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "restore-n8n: check_volume function exists" {
	run grep -q "check_volume()" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Argument Validation Tests
# -----------------------------------------------------------------------------

@test "restore-n8n: requires backup file argument" {
	run grep -q '\$# -ne 1' "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: validates .tar.gz extension" {
	run grep -q '\.tar\.gz' "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: checks if backup file exists" {
	run grep -q 'Backup file not found' "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: verifies gzip integrity" {
	run grep -q "gunzip -t" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Encrypted Backup Tests
# -----------------------------------------------------------------------------

@test "restore-n8n: decrypt_backup_file function exists" {
	run grep -q "decrypt_backup_file()" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: accepts .tar.gz.gpg files" {
	run grep -q "\.tar\.gz\.gpg" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: detects encrypted backup files" {
	run grep -q "IS_ENCRYPTED" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: uses GPG for decryption" {
	run grep -q "\-\-decrypt" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: reads passphrase from BACKUP_GPG_PASSPHRASE" {
	run grep -q "BACKUP_GPG_PASSPHRASE" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: creates temp file for decryption" {
	run grep -q "mktemp" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Safety Tests
# -----------------------------------------------------------------------------

@test "restore-n8n: shows warning before restore" {
	run grep -q "log_warn" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: prompts for confirmation in interactive mode" {
	run grep -q "read -r" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: creates safety backup before overwriting" {
	run grep -q "safety backup\|prerestore" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: uses docker volume for restore" {
	run grep -q "docker.*volume\|VOLUME_NAME" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "restore-n8n: script is executable" {
	assert [ -x "$SCRIPTS_DIR/restore-n8n.sh" ]
}

@test "restore-n8n: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: has usage function" {
	run grep -q "usage()" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: shows usage for encrypted files" {
	run grep -q "backup_file.tar.gz.gpg" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: uses alpine container for restore" {
	run grep -q "alpine" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}

@test "restore-n8n: verifies restore by counting files" {
	run grep -q "find.*wc\|FILE_COUNT" "$SCRIPTS_DIR/restore-n8n.sh"
	assert_success
}
