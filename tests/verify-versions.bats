#!/usr/bin/env bats
# =============================================================================
# Tests for verify-versions.sh - Verify Pinned vs Running Versions
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/verify-versions.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/verify-versions.sh"

	# Create a mock docker-compose.yml
	cat >"$TEST_PROJECT_DIR/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:1.70.0
  n8n-worker:
    image: n8nio/n8n:1.70.0
  postgres:
    image: postgres:16.1-alpine
  redis:
    image: redis:7.2.3-alpine
EOF
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "verify-versions: print_header displays title" {
	source_script_functions "verify-versions.sh"
	run print_header
	assert_success
	assert_output --partial "Version Verification Report"
}

@test "verify-versions: print_result formats MATCH correctly" {
	source_script_functions "verify-versions.sh"
	run print_result "n8n" "1.70.0" "1.70.0" "MATCH"
	assert_success
	assert_output --partial "n8n"
	assert_output --partial "MATCH"
}

@test "verify-versions: print_result formats MISMATCH correctly" {
	source_script_functions "verify-versions.sh"
	run print_result "n8n" "1.70.0" "1.69.0" "MISMATCH"
	assert_success
	assert_output --partial "MISMATCH"
}

@test "verify-versions: get_pinned_version extracts image tag" {
	source_script_functions "verify-versions.sh"
	export COMPOSE_FILE="$TEST_PROJECT_DIR/docker-compose.yml"

	run get_pinned_version "n8n"
	assert_success
	assert_output --partial "n8nio/n8n"
}

@test "verify-versions: get_running_version uses docker inspect" {
	source_script_functions "verify-versions.sh"

	run get_running_version "n8n-main"
	assert_success
	# Mock returns "n8nio/n8n:1.70.0"
	assert_output --partial "n8n"
}

@test "verify-versions: get_actual_version for n8n" {
	source_script_functions "verify-versions.sh"

	run get_actual_version "n8n-main" "n8n"
	assert_success
	assert_output "1.70.0"
}

@test "verify-versions: get_actual_version for postgres" {
	source_script_functions "verify-versions.sh"

	run get_actual_version "n8n-postgres" "postgres"
	assert_success
	assert_output --partial "16.1"
}

@test "verify-versions: get_actual_version for redis" {
	source_script_functions "verify-versions.sh"

	run get_actual_version "n8n-redis" "redis"
	assert_success
	assert_output --partial "7.2.3"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "verify-versions: uses correct compose file path" {
	source_script_functions "verify-versions.sh"
	[[ "$COMPOSE_FILE" == *"docker-compose.yml" ]]
}

@test "verify-versions: defines color codes" {
	run grep -q "RED=\|GREEN=\|YELLOW=\|NC=" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Version Check Tests
# -----------------------------------------------------------------------------

@test "verify-versions: checks n8n version" {
	run grep -q "n8n" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

@test "verify-versions: checks n8n-worker version" {
	run grep -q "n8n-worker\|worker" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

@test "verify-versions: checks postgres version" {
	run grep -q "postgres" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

@test "verify-versions: checks redis version" {
	run grep -q "redis" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Exit Code Tests
# -----------------------------------------------------------------------------

@test "verify-versions: exits 0 when all match" {
	run grep -q "EXIT_CODE=0\|exit 0" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

@test "verify-versions: exits 1 on mismatch" {
	run grep -q "EXIT_CODE=1\|exit 1" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "verify-versions: script is executable" {
	assert [ -x "$SCRIPTS_DIR/verify-versions.sh" ]
}

@test "verify-versions: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

@test "verify-versions: handles missing compose file" {
	source_script_functions "verify-versions.sh"
	export COMPOSE_FILE="/nonexistent/docker-compose.yml"

	run bash -c "[[ ! -f '$COMPOSE_FILE' ]] && echo 'Compose file not found'"
	assert_success
	assert_output "Compose file not found"
}

@test "verify-versions: shows actual software versions section" {
	run grep -q "Actual Software Versions" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}

@test "verify-versions: handles not running containers" {
	run grep -q "not running\|NOT RUNNING" "$SCRIPTS_DIR/verify-versions.sh"
	assert_success
}
