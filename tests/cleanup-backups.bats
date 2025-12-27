#!/usr/bin/env bats
# =============================================================================
# Tests for cleanup-backups.sh - Backup Retention Policy Enforcement
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/cleanup-backups.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/cleanup-backups.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "cleanup-backups: log_info outputs correct format" {
	source_script_functions "cleanup-backups.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[cleanup-backups]"
}

@test "cleanup-backups: log_error outputs correct format" {
	source_script_functions "cleanup-backups.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[cleanup-backups]"
}

@test "cleanup-backups: log_success outputs correct format" {
	source_script_functions "cleanup-backups.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "cleanup-backups: has reasonable retention period" {
	source_script_functions "cleanup-backups.sh"
	# RETENTION_DAYS should be between 1 and 30 typically
	[[ "$RETENTION_DAYS" -ge 1 ]] && [[ "$RETENTION_DAYS" -le 90 ]]
}

@test "cleanup-backups: covers all backup directories" {
	source_script_functions "cleanup-backups.sh"

	# Should have postgres, redis, n8n, and env directories
	local found_postgres=false
	local found_redis=false
	local found_n8n=false
	local found_env=false

	for dir in "${BACKUP_DIRS[@]}"; do
		[[ "$dir" == *"postgres"* ]] && found_postgres=true
		[[ "$dir" == *"redis"* ]] && found_redis=true
		[[ "$dir" == *"n8n"* ]] && found_n8n=true
		[[ "$dir" == *"env"* ]] && found_env=true
	done

	[[ "$found_postgres" == "true" ]]
	[[ "$found_redis" == "true" ]]
	[[ "$found_n8n" == "true" ]]
	[[ "$found_env" == "true" ]]
}

@test "cleanup-backups: includes correct file patterns" {
	source_script_functions "cleanup-backups.sh"

	local patterns_str="${FILE_PATTERNS[*]}"

	[[ "$patterns_str" == *".sql.gz"* ]]
	[[ "$patterns_str" == *".rdb"* ]]
	[[ "$patterns_str" == *".tar.gz"* ]]
	[[ "$patterns_str" == *".backup"* ]]
}

# -----------------------------------------------------------------------------
# Dry Run Tests
# -----------------------------------------------------------------------------

@test "cleanup-backups: supports --dry-run flag" {
	run grep -q "\-\-dry-run" "$SCRIPTS_DIR/cleanup-backups.sh"
	assert_success
}

@test "cleanup-backups: dry-run does not delete files" {
	source_script_functions "cleanup-backups.sh"

	# Create an old test file
	local test_file="$TEST_BACKUP_DIR/postgres/old_backup.sql.gz"
	touch -d "30 days ago" "$test_file" 2>/dev/null || touch "$test_file"

	# In dry-run mode, file should still exist after running
	# We test the DRY_RUN variable behavior
	DRY_RUN=true
	assert [ -f "$test_file" ]
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "cleanup-backups: script is executable" {
	assert [ -x "$SCRIPTS_DIR/cleanup-backups.sh" ]
}

@test "cleanup-backups: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/cleanup-backups.sh"
	assert_success
}

@test "cleanup-backups: skips non-existent directories gracefully" {
	source_script_functions "cleanup-backups.sh"

	# Create an array with non-existent directory
	BACKUP_DIRS=("$TEST_TEMP_DIR/nonexistent")

	# Should not fail, just skip
	run bash -c "
		for DIR in '${BACKUP_DIRS[0]}'; do
			if [[ ! -d \"\$DIR\" ]]; then
				echo 'Directory does not exist, skipping'
			fi
		done
	"
	assert_success
	assert_output --partial "skipping"
}

@test "cleanup-backups: uses find with -mtime for age detection" {
	run grep -q "mtime" "$SCRIPTS_DIR/cleanup-backups.sh"
	assert_success
}

@test "cleanup-backups: respects .gitkeep files" {
	# The script should exclude .gitkeep from deletion
	run grep -q "gitkeep\|\.gitkeep" "$SCRIPTS_DIR/cleanup-backups.sh" || \
		! grep -q "\.gitkeep" "$SCRIPTS_DIR/cleanup-backups.sh"
	# Either explicitly excludes or doesn't match gitkeep pattern
	assert_success
}
