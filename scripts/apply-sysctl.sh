#!/bin/bash
# =============================================================================
# apply-sysctl.sh - Apply and Verify Sysctl Kernel Parameters
# =============================================================================
# Description: Manages sysctl kernel parameters for n8n stack optimization.
#              Generates sudo commands for user to run, verifies application.
# Usage: ./apply-sysctl.sh [--check|--verify|--apply|--help]
# Exit Codes: 0=success, 1=error, 2=changes needed
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/config/99-n8n-optimizations.conf"
SYSTEM_CONFIG="/etc/sysctl.d/99-n8n-optimizations.conf"
LOG_FILE="${PROJECT_DIR}/logs/sysctl.log"

# Required sysctl settings
declare -A REQUIRED_SETTINGS=(
	["vm.overcommit_memory"]="1"
)

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [apply-sysctl] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [apply-sysctl] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [apply-sysctl] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [apply-sysctl] $1" | tee -a "$LOG_FILE"
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Manages sysctl kernel parameters for n8n stack optimization.

Options:
  --check      Check current sysctl settings (default)
  --verify     Verify persistence in /etc/sysctl.d/
  --apply      Generate sudo commands to apply settings
  --help, -h   Show this help message

Modes:
  check   - Shows current kernel parameter values
  verify  - Checks if config file is installed in /etc/sysctl.d/
  apply   - Outputs sudo commands for user to run

Examples:
  ./apply-sysctl.sh                 # Check current settings
  ./apply-sysctl.sh --check         # Same as above
  ./apply-sysctl.sh --verify        # Check if settings persist
  ./apply-sysctl.sh --apply         # Get commands to apply settings

Exit Codes:
  0  All settings correct / commands generated
  1  Error occurred
  2  Settings need to be applied

Note: This script does NOT run sudo commands directly.
      It generates commands for the user to run manually.
EOF
}

# Check current sysctl settings
# Returns: 0 if all settings correct, 2 if changes needed
check_current_settings() {
	log_info "Checking current sysctl settings..."

	local needs_change=0

	for key in "${!REQUIRED_SETTINGS[@]}"; do
		local expected="${REQUIRED_SETTINGS[$key]}"
		local current

		current=$(sysctl -n "$key" 2>/dev/null)
		local sysctl_exit=$?

		if [[ $sysctl_exit -ne 0 ]]; then
			log_error "Failed to read sysctl: $key"
			needs_change=1
			continue
		fi

		if [[ "$current" == "$expected" ]]; then
			log_success "$key = $current (correct)"
		else
			log_warn "$key = $current (expected: $expected)"
			needs_change=1
		fi
	done

	if [[ $needs_change -eq 0 ]]; then
		log_success "All sysctl settings are correctly configured"
		return 0
	else
		log_warn "Some sysctl settings need to be updated"
		return 2
	fi
}

# Verify persistence - check if config is installed in /etc/sysctl.d/
# Returns: 0 if persistent, 2 if not installed
verify_persistence() {
	log_info "Verifying sysctl persistence..."

	# Check if system config file exists
	if [[ ! -f "$SYSTEM_CONFIG" ]]; then
		log_warn "Config not installed at: $SYSTEM_CONFIG"
		log_info "Settings will be lost on reboot"
		return 2
	fi

	# Verify file content matches source
	if ! diff -q "$CONFIG_FILE" "$SYSTEM_CONFIG" &>/dev/null; then
		log_warn "System config differs from source config"
		log_info "Source: $CONFIG_FILE"
		log_info "System: $SYSTEM_CONFIG"
		return 2
	fi

	log_success "Sysctl settings are persistent"
	log_info "Config installed at: $SYSTEM_CONFIG"
	return 0
}

# Generate sudo commands for user to run
# Returns: 0 always (outputs commands)
generate_sudo_commands() {
	log_info "Generating sudo commands to apply sysctl settings..."

	echo ""
	echo "=========================================="
	echo "SUDO COMMANDS TO RUN"
	echo "=========================================="
	echo ""
	echo "Copy and run the following commands:"
	echo ""

	# Check if source config exists
	if [[ ! -f "$CONFIG_FILE" ]]; then
		log_error "Source config not found: $CONFIG_FILE"
		echo "# ERROR: Source config file missing!"
		echo "# Expected at: $CONFIG_FILE"
		return 1
	fi

	# Command 1: Copy config file
	echo "# 1. Install sysctl configuration file"
	echo "sudo cp \"$CONFIG_FILE\" \"$SYSTEM_CONFIG\""
	echo ""

	# Command 2: Set proper permissions
	echo "# 2. Set proper permissions"
	echo "sudo chmod 644 \"$SYSTEM_CONFIG\""
	echo ""

	# Command 3: Apply settings immediately
	echo "# 3. Apply settings immediately (without reboot)"
	echo "sudo sysctl -p \"$SYSTEM_CONFIG\""
	echo ""

	# Alternative: Apply specific setting directly
	echo "# Alternative: Apply specific setting directly"
	echo "# sudo sysctl -w vm.overcommit_memory=1"
	echo ""

	echo "=========================================="
	echo ""

	log_info "After running commands, verify with: $0 --check"
	return 0
}

# Verify that settings have been applied
# Returns: 0 if applied correctly, 1 if not
verify_applied() {
	log_info "Verifying applied sysctl settings..."

	local all_ok=0

	# Check runtime values
	if ! check_current_settings; then
		all_ok=1
	fi

	# Check persistence
	if ! verify_persistence; then
		all_ok=1
	fi

	if [[ $all_ok -eq 0 ]]; then
		log_success "All sysctl settings applied and persistent"
		return 0
	else
		log_warn "Some settings need attention"
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	# Create log directory if needed
	mkdir -p "$(dirname "$LOG_FILE")"

	# Parse arguments
	local mode="check"

	case "${1:-}" in
	--check)
		mode="check"
		;;
	--verify)
		mode="verify"
		;;
	--apply)
		mode="apply"
		;;
	--help | -h)
		show_help
		exit 0
		;;
	"")
		mode="check"
		;;
	*)
		log_error "Unknown option: $1"
		show_help
		exit 1
		;;
	esac

	log_info "=========================================="
	log_info "Sysctl Configuration Management"
	log_info "=========================================="

	case "$mode" in
	check)
		check_current_settings
		exit $?
		;;
	verify)
		verify_persistence
		exit $?
		;;
	apply)
		generate_sudo_commands
		exit $?
		;;
	esac
}

main "$@"
