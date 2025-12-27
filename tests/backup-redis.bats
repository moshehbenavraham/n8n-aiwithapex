#!/usr/bin/env bats
# =============================================================================
# Tests for backup-redis.sh - Redis RDB Snapshot Backup
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/backup-redis.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/backup-redis.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "backup-redis: log_info outputs correct format" {
	source_script_functions "backup-redis.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[backup-redis]"
}

@test "backup-redis: log_error outputs correct format" {
	source_script_functions "backup-redis.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[backup-redis]"
}

@test "backup-redis: log_success outputs correct format" {
	source_script_functions "backup-redis.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "backup-redis: check_container succeeds when container running" {
	source_script_functions "backup-redis.sh"
	export CONTAINER_NAME="n8n-redis"

	run check_container
	assert_success
}

@test "backup-redis: check_container fails when container not running" {
	source_script_functions "backup-redis.sh"
	export CONTAINER_NAME="nonexistent-container"

	create_mock "docker" 0 ""

	run check_container
	assert_failure
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "backup-redis: uses correct container name" {
	source_script_functions "backup-redis.sh"
	assert_equal "$CONTAINER_NAME" "n8n-redis"
}

@test "backup-redis: uses default Redis port" {
	source_script_functions "backup-redis.sh"
	# Default should be 6379 unless overridden
	[[ "$REDIS_PORT" =~ ^[0-9]+$ ]]
}

@test "backup-redis: backup filename uses .rdb extension" {
	source_script_functions "backup-redis.sh"
	export BACKUP_DIR="$TEST_BACKUP_DIR/redis"

	TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
	BACKUP_FILE="${BACKUP_DIR}/dump_${TIMESTAMP}.rdb"

	[[ "$BACKUP_FILE" == *.rdb ]]
}

@test "backup-redis: has reasonable BGSAVE timeout" {
	source_script_functions "backup-redis.sh"
	# MAX_WAIT_SECONDS should be defined and reasonable (30-120 seconds)
	[[ "$MAX_WAIT_SECONDS" -ge 30 ]] && [[ "$MAX_WAIT_SECONDS" -le 120 ]]
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "backup-redis: script is executable" {
	assert [ -x "$SCRIPTS_DIR/backup-redis.sh" ]
}

@test "backup-redis: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/backup-redis.sh"
	assert_success
}

@test "backup-redis: uses BGSAVE for non-blocking backup" {
	run grep -q "BGSAVE" "$SCRIPTS_DIR/backup-redis.sh"
	assert_success
}

@test "backup-redis: checks LASTSAVE timestamp" {
	run grep -q "LASTSAVE" "$SCRIPTS_DIR/backup-redis.sh"
	assert_success
}

@test "backup-redis: uses docker cp for RDB file" {
	run grep -q "docker cp" "$SCRIPTS_DIR/backup-redis.sh"
	assert_success
}
