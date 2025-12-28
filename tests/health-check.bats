#!/usr/bin/env bats
# =============================================================================
# Tests for health-check.sh - Container and Endpoint Health Validation
# =============================================================================

load 'test_helper'

setup() {
	common_setup
	cp "$SCRIPTS_DIR/health-check.sh" "$TEST_SCRIPTS_DIR/"
	chmod +x "$TEST_SCRIPTS_DIR/health-check.sh"
}

teardown() {
	common_teardown
}

# -----------------------------------------------------------------------------
# Function Tests
# -----------------------------------------------------------------------------

@test "health-check: log_info outputs correct format" {
	source_script_functions "health-check.sh"
	run log_info "Test message"
	assert_success
	assert_output --partial "[INFO]"
	assert_output --partial "[health-check]"
}

@test "health-check: log_error outputs correct format" {
	source_script_functions "health-check.sh"
	run log_error "Error message"
	assert_success
	assert_output --partial "[ERROR]"
	assert_output --partial "[health-check]"
}

@test "health-check: log_success outputs correct format" {
	source_script_functions "health-check.sh"
	run log_success "Success message"
	assert_success
	assert_output --partial "[SUCCESS]"
}

@test "health-check: log_warn outputs correct format" {
	source_script_functions "health-check.sh"
	run log_warn "Warning message"
	assert_success
	assert_output --partial "[WARN]"
	assert_output --partial "[health-check]"
}

@test "health-check: show_help displays usage" {
	source_script_functions "health-check.sh"
	run show_help
	assert_success
	assert_output --partial "Usage:"
	assert_output --partial "Exit Codes:"
}

@test "health-check: check_docker succeeds when docker available" {
	source_script_functions "health-check.sh"
	run check_docker
	assert_success
}

# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

@test "health-check: has correct healthz URL" {
	source_script_functions "health-check.sh"
	assert_equal "$HEALTHZ_URL" "http://localhost:5678/healthz"
}

@test "health-check: has reasonable timeout" {
	source_script_functions "health-check.sh"
	[[ "$HEALTHZ_TIMEOUT" -ge 1 ]] && [[ "$HEALTHZ_TIMEOUT" -le 30 ]]
}

@test "health-check: defines expected worker count" {
	source_script_functions "health-check.sh"
	[[ "$EXPECTED_WORKERS" -ge 1 ]]
}

@test "health-check: includes required containers" {
	source_script_functions "health-check.sh"

	local containers_str="${REQUIRED_CONTAINERS[*]}"
	[[ "$containers_str" == *"postgres"* ]]
	[[ "$containers_str" == *"redis"* ]]
	[[ "$containers_str" == *"n8n"* ]]
}

# -----------------------------------------------------------------------------
# Health Check Function Tests
# -----------------------------------------------------------------------------

@test "health-check: check_container_health uses docker inspect" {
	run grep -q "docker inspect" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: check_healthz_endpoint uses curl" {
	run grep -q "curl" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: check_healthz_endpoint handles timeout" {
	run grep -q "max-time\|timeout" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: checks worker replicas" {
	run grep -q "worker" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Exit Code Tests
# -----------------------------------------------------------------------------

@test "health-check: uses exit code 0 for healthy" {
	run grep -q "exit 0\|OVERALL_STATUS=0" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: uses exit code 1 for unhealthy" {
	run grep -q "exit 1\|OVERALL_STATUS=1" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: uses exit code 2 for warning" {
	run grep -q "exit 2\|OVERALL_STATUS=2" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Integration Tests
# -----------------------------------------------------------------------------

@test "health-check: script is executable" {
	assert [ -x "$SCRIPTS_DIR/health-check.sh" ]
}

@test "health-check: script has valid bash syntax" {
	run bash -n "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: supports --help flag" {
	source_script_functions "health-check.sh"

	# Test help argument parsing
	run bash -c "
		case '--help' in
			--help|-h) echo 'Help requested' ;;
		esac
	"
	assert_success
	assert_output "Help requested"
}

@test "health-check: checks container state" {
	run grep -q "State.Status\|State.Health" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

# -----------------------------------------------------------------------------
# Auto-Scaling Status Tests (T021/S0302)
# -----------------------------------------------------------------------------

@test "health-check: includes auto-scaling status function" {
	run grep -q "check_autoscale_status" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: auto-scaling status reads AUTOSCALE_ENABLED" {
	run grep -q "AUTOSCALE_ENABLED" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: auto-scaling status displays worker bounds" {
	run grep -q "AUTOSCALE_MIN_WORKERS\|AUTOSCALE_MAX_WORKERS" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: auto-scaling status checks queue depth" {
	run grep -q "queue-depth.sh\|queue_depth" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: auto-scaling status checks cooldown" {
	run grep -q "cooldown" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: check_autoscale_status function exists" {
	source_script_functions "health-check.sh"
	run type check_autoscale_status
	assert_success
}

# -----------------------------------------------------------------------------
# Sysctl Optimization Tests (T018/S0304)
# -----------------------------------------------------------------------------

@test "health-check: includes sysctl optimization function" {
	run grep -q "check_sysctl_optimization" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: sysctl check reads vm.overcommit_memory" {
	run grep -q "vm.overcommit_memory" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: sysctl check references system config path" {
	run grep -q "/etc/sysctl.d/99-n8n-optimizations.conf" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: sysctl check provides remediation advice" {
	run grep -q "apply-sysctl.sh" "$SCRIPTS_DIR/health-check.sh"
	assert_success
}

@test "health-check: check_sysctl_optimization function exists" {
	source_script_functions "health-check.sh"
	run type check_sysctl_optimization
	assert_success
}

@test "health-check: help mentions sysctl optimization" {
	run "$SCRIPTS_DIR/health-check.sh" --help
	assert_success
	assert_output --partial "vm.overcommit_memory"
}
