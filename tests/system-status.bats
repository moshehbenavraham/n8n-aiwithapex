#!/usr/bin/env bats
# =============================================================================
# Tests for system-status.sh - Dashboard-Style System Status Report
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/system-status.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/system-status.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "system-status: log_error outputs correct format" {
	source_script_functions "system-status.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[system-status]"
}

@test "system-status: show_help displays usage" {
	source_script_functions "system-status.sh"
	run show_help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "dashboard"
}

@test "system-status: print_separator outputs separator" {
	source_script_functions "system-status.sh"
	run print_separator
	assert_success
	assert_output --partial "===="
}

@test "system-status: print_section_header outputs header" {
	source_script_functions "system-status.sh"
	run print_section_header "TEST SECTION"
	assert_success
	assert_output --partial "TEST SECTION"
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "system-status: has correct healthz URL" {
	source_script_functions "system-status.sh"
	assert_equal "$HEALTHZ_URL" "http://localhost:5678/healthz"
}

@test "system-status: has correct n8n URL" {
	source_script_functions "system-status.sh"
	assert_equal "$N8N_URL" "http://localhost:5678"
}

@test "system-status: has metrics URL" {
	source_script_functions "system-status.sh"
	assert_equal "$METRICS_URL" "http://localhost:5678/metrics"
}

# -----------------------------------------------------------------------------
# Dashboard Section Tests
# -----------------------------------------------------------------------------

@test "system-status: has container status section" {
	run grep -q "CONTAINER STATUS\|show_container_status" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: has resource summary section" {
	run grep -q "RESOURCE USAGE\|show_resource_summary" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: has queue status section" {
	run grep -q "QUEUE STATUS\|show_queue_status" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: has endpoint status section" {
	run grep -q "ENDPOINT STATUS\|show_endpoint_status" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Queue Monitoring Tests
# -----------------------------------------------------------------------------

@test "system-status: queries Redis for queue info" {
	run grep -q "redis-cli" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: checks Bull queue keys" {
	run grep -q "bull:" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: shows waiting/active/completed/failed counts" {
	run grep -q "Waiting\|Active\|Completed\|Failed" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Endpoint Monitoring Tests
# -----------------------------------------------------------------------------

@test "system-status: checks healthz endpoint" {
	run grep -q "healthz" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: checks PostgreSQL connection" {
	run grep -q "pg_isready" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: checks Redis connection" {
	run grep -q "PING\|PONG" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "system-status: script is executable" {
	assert [ -x "$SCRIPTS_DIR/system-status.sh" ]
}

@test "system-status: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: supports --json flag" {
	run grep -q "\-\-json" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: supports --help flag" {
	run grep -q "\-\-help\|\-h" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: displays timestamp" {
	run grep -q "date" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: counts workers" {
	run grep -q "worker" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}

@test "system-status: shows overall status" {
	run grep -q "ALL SYSTEMS HEALTHY\|WARNINGS DETECTED\|ISSUES DETECTED" "$SCRIPTS_DIR/system-status.sh"
	assert_success
}
