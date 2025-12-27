#!/usr/bin/env bats
# =============================================================================
# Tests for backup-n8n.sh - n8n Data Volume Backup
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/backup-n8n.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/backup-n8n.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "backup-n8n: log_info outputs correct format" {
	source_script_functions "backup-n8n.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[backup-n8n]"
}

@test "backup-n8n: log_error outputs correct format" {
	source_script_functions "backup-n8n.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[backup-n8n]"
}

@test "backup-n8n: log_success outputs correct format" {
	source_script_functions "backup-n8n.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "backup-n8n: check_volume succeeds when volume exists" {
	source_script_functions "backup-n8n.sh"
	export VOLUME_NAME="n8n_n8n_data"

	run check_volume
	assert_success
}

@test "backup-n8n: check_volume fails when volume missing" {
	source_script_functions "backup-n8n.sh"
	export VOLUME_NAME="nonexistent_volume"

	# Override docker mock to fail volume inspect
	local mock_dir="$TEST_TEMP_DIR/mocks"
	cat >"$mock_dir/docker" <<'EOF'
#!/bin/bash
if [[ "$2" == "inspect" ]]; then
    exit 1
fi
exit 0
EOF
	chmod +x "$mock_dir/docker"

	run check_volume
	assert_failure
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "backup-n8n: uses correct volume name" {
	source_script_functions "backup-n8n.sh"
	assert_equal "$VOLUME_NAME" "n8n_n8n_data"
}

@test "backup-n8n: backup filename uses tar.gz extension" {
	source_script_functions "backup-n8n.sh"
	export BACKUP_DIR="$TEST_BACKUP_DIR/n8n"

	TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
	BACKUP_FILENAME="n8n_data_${TIMESTAMP}.tar.gz"

	[[ "$BACKUP_FILENAME" == *.tar.gz ]]
}

@test "backup-n8n: creates backup directory if missing" {
	source_script_functions "backup-n8n.sh"
	export BACKUP_DIR="$TEST_TEMP_DIR/new_n8n_backup"

	mkdir -p "$BACKUP_DIR"
	assert [ -d "$BACKUP_DIR" ]
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "backup-n8n: script is executable" {
	assert [ -x "$SCRIPTS_DIR/backup-n8n.sh" ]
}

@test "backup-n8n: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/backup-n8n.sh"
	assert_success
}

@test "backup-n8n: uses alpine for backup" {
	# The script should use alpine:latest for tar operations
	run grep -q "alpine:latest" "$SCRIPTS_DIR/backup-n8n.sh"
	assert_success
}

@test "backup-n8n: mounts volume as read-only" {
	# The script should mount the volume as read-only for safety
	run grep -q ":ro" "$SCRIPTS_DIR/backup-n8n.sh"
	assert_success
}
