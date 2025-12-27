#!/usr/bin/env bats
# =============================================================================
# Tests for backup-offsite.sh - Off-site Backup Synchronization
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/backup-offsite.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/backup-offsite.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "backup-offsite: log_info outputs correct format" {
	log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [backup-offsite] $1"; }
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[backup-offsite]"
}

@test "backup-offsite: log_error outputs correct format" {
	log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-offsite] $1"; }
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[backup-offsite]"
}

@test "backup-offsite: log_success outputs correct format" {
	log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [backup-offsite] $1"; }
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "backup-offsite: uses RCLONE_REMOTE variable" {
	run grep -q "RCLONE_REMOTE" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: uses RCLONE_BUCKET variable" {
	run grep -q "RCLONE_BUCKET" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: supports RCLONE_SYNC_ENCRYPTED_ONLY" {
	run grep -q "RCLONE_SYNC_ENCRYPTED_ONLY" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: has default for RCLONE_REMOTE" {
	run grep -q 'RCLONE_REMOTE:-n8n-backup' "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: has default for RCLONE_BUCKET" {
	run grep -q 'RCLONE_BUCKET:-n8n-backups' "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Lock File Tests
# -----------------------------------------------------------------------------

@test "backup-offsite: uses separate lock file from backup-all.sh" {
	run grep -q "n8n-offsite.lock" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: has cleanup_lock function" {
	run grep -q "cleanup_lock()" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# rclone Integration Tests
# -----------------------------------------------------------------------------

@test "backup-offsite: checks for rclone installation" {
	run grep -q "command -v rclone" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: verifies remote configuration" {
	run grep -q "rclone listremotes" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: uses rclone sync command" {
	run grep -q "rclone sync" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: supports --dry-run option" {
	run grep -q "\-\-dry-run" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: filters for .gpg files when encrypted only" {
	run grep -q '\.gpg' "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "backup-offsite: script is executable" {
	assert [ -x "$SCRIPTS_DIR/backup-offsite.sh" ]
}

@test "backup-offsite: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: has usage function" {
	run grep -q "usage()" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: supports --help option" {
	run grep -q "\-\-help" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}

@test "backup-offsite: shows progress during sync" {
	run grep -q "\-\-progress" "$SCRIPTS_DIR/backup-offsite.sh"
	assert_success
}
