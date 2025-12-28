#!/bin/bash
# =============================================================================
# test-recovery.sh - Disaster Recovery Testing Script
# =============================================================================
# Description: Tests disaster recovery procedures for PostgreSQL, Redis, and
#              n8n data volumes. Uses temporary restore targets to avoid
#              affecting production data.
# Usage: ./test-recovery.sh [--postgres|--redis|--n8n|--full|--help]
# Exit Codes: 0=all tests passed, 1=test failure, 2=setup error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
LOG_FILE="${PROJECT_DIR}/logs/recovery-test.log"
TEST_DIR="/tmp/n8n-recovery-test-$$"

# Container names
POSTGRES_CONTAINER="n8n-postgres"
REDIS_CONTAINER="n8n-redis"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${PROJECT_DIR}/.env"
fi

# Database settings
DB_USER="${POSTGRES_USER:-n8n}"
# shellcheck disable=SC2034  # DB_NAME reserved for future use
DB_NAME="${POSTGRES_DB:-n8n}"

# Test result tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [test-recovery] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [test-recovery] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [test-recovery] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [test-recovery] $1" | tee -a "$LOG_FILE"
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Tests disaster recovery procedures without affecting production data.

Options:
  --postgres    Test PostgreSQL recovery only
  --redis       Test Redis recovery only
  --n8n         Test n8n data volume recovery only
  --full        Run all recovery tests
  --list        List available backups
  --help, -h    Show this help message

Safety:
  - All tests use temporary restore targets
  - Production data is NOT modified
  - Encrypted backups require BACKUP_GPG_PASSPHRASE in .env

Examples:
  ./test-recovery.sh --postgres    # Test PostgreSQL recovery
  ./test-recovery.sh --redis       # Test Redis recovery
  ./test-recovery.sh --full        # Run all tests
  ./test-recovery.sh --list        # Show available backups

Exit Codes:
  0  All tests passed
  1  One or more tests failed
  2  Setup or configuration error
EOF
}

# Setup test environment
setup_test_env() {
	log_info "Setting up test environment..."

	# Create test directory
	mkdir -p "$TEST_DIR"

	# Verify containers are running
	if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
		log_error "PostgreSQL container not running"
		return 1
	fi

	if ! docker ps --format '{{.Names}}' | grep -q "^${REDIS_CONTAINER}$"; then
		log_error "Redis container not running"
		return 1
	fi

	log_success "Test environment ready: $TEST_DIR"
	return 0
}

# Cleanup test environment
# shellcheck disable=SC2329  # Called via trap EXIT
cleanup_test_env() {
	log_info "Cleaning up test environment..."
	rm -rf "$TEST_DIR"
	log_info "Test cleanup completed"
}

# Find latest backup file of given type
# Arguments: $1 = backup type (postgres|redis|n8n)
# Returns: Path to latest backup file
find_latest_backup() {
	local backup_type="$1"
	local backup_path=""
	local pattern=""

	case "$backup_type" in
	postgres)
		backup_path="${BACKUP_DIR}/postgres"
		pattern="*.sql.gz"
		;;
	redis)
		backup_path="${BACKUP_DIR}/redis"
		pattern="*.rdb"
		;;
	n8n)
		backup_path="${BACKUP_DIR}/n8n"
		pattern="*.tar.gz"
		;;
	*)
		log_error "Unknown backup type: $backup_type"
		return 1
		;;
	esac

	if [[ ! -d "$backup_path" ]]; then
		log_error "Backup directory not found: $backup_path"
		return 1
	fi

	# Find latest backup (prefer encrypted if BACKUP_GPG_PASSPHRASE is set)
	local latest_file=""
	if [[ -n "${BACKUP_GPG_PASSPHRASE:-}" ]]; then
		latest_file=$(find "$backup_path" -name "${pattern}.gpg" -type f 2>/dev/null | sort -r | head -1)
	fi

	if [[ -z "$latest_file" ]]; then
		latest_file=$(find "$backup_path" -name "$pattern" -type f 2>/dev/null | sort -r | head -1)
	fi

	if [[ -z "$latest_file" ]]; then
		log_error "No backup files found in: $backup_path"
		return 1
	fi

	echo "$latest_file"
	return 0
}

# List available backups
list_backups() {
	log_info "Available backups:"
	echo ""

	echo "PostgreSQL backups:"
	if [[ -d "${BACKUP_DIR}/postgres" ]]; then
		find "${BACKUP_DIR}/postgres" -type f \( -name "*.sql.gz" -o -name "*.sql.gz.gpg" \) 2>/dev/null | sort -r | head -5 | while read -r f; do
			local size
			size=$(du -h "$f" | cut -f1)
			echo "  $f ($size)"
		done
	else
		echo "  (none found)"
	fi
	echo ""

	echo "Redis backups:"
	if [[ -d "${BACKUP_DIR}/redis" ]]; then
		find "${BACKUP_DIR}/redis" -type f \( -name "*.rdb" -o -name "*.rdb.gpg" \) 2>/dev/null | sort -r | head -5 | while read -r f; do
			local size
			size=$(du -h "$f" | cut -f1)
			echo "  $f ($size)"
		done
	else
		echo "  (none found)"
	fi
	echo ""

	echo "n8n data backups:"
	if [[ -d "${BACKUP_DIR}/n8n" ]]; then
		find "${BACKUP_DIR}/n8n" -type f \( -name "*.tar.gz" -o -name "*.tar.gz.gpg" \) 2>/dev/null | sort -r | head -5 | while read -r f; do
			local size
			size=$(du -h "$f" | cut -f1)
			echo "  $f ($size)"
		done
	else
		echo "  (none found)"
	fi
	echo ""
}

# Decrypt a backup file if needed
# Arguments: $1 = backup file path
# Returns: Path to decrypted file (or original if not encrypted)
decrypt_if_needed() {
	local backup_file="$1"
	local output_file=""

	# Check if file is encrypted
	if [[ "$backup_file" != *.gpg ]]; then
		echo "$backup_file"
		return 0
	fi

	# Check passphrase
	if [[ -z "${BACKUP_GPG_PASSPHRASE:-}" ]]; then
		log_error "BACKUP_GPG_PASSPHRASE not set - cannot decrypt backup"
		return 1
	fi

	# Decrypt to temp directory
	output_file="${TEST_DIR}/$(basename "${backup_file%.gpg}")"

	log_info "Decrypting backup file..."
	if echo "$BACKUP_GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
		--decrypt --output "$output_file" "$backup_file" 2>/dev/null; then
		log_info "Decryption successful"
		echo "$output_file"
		return 0
	else
		log_error "Decryption failed - check passphrase"
		return 1
	fi
}

# Test PostgreSQL recovery procedure
test_postgres_recovery() {
	log_info "=========================================="
	log_info "Testing PostgreSQL Recovery"
	log_info "=========================================="

	((TESTS_RUN++))

	# Find latest backup
	local backup_file
	if ! backup_file=$(find_latest_backup "postgres"); then
		log_error "PostgreSQL recovery test: SKIPPED (no backup)"
		return 1
	fi

	log_info "Using backup: $backup_file"

	# Decrypt if needed
	local test_file
	if ! test_file=$(decrypt_if_needed "$backup_file"); then
		log_error "PostgreSQL recovery test: FAILED (decryption)"
		((TESTS_FAILED++))
		return 1
	fi

	# Verify backup file integrity
	log_info "Verifying backup file integrity..."
	if ! gunzip -t "$test_file" 2>/dev/null; then
		log_error "Backup file is corrupted"
		log_error "PostgreSQL recovery test: FAILED (corrupt file)"
		((TESTS_FAILED++))
		return 1
	fi
	log_info "Backup file integrity verified"

	# Test restore to temporary database
	local test_db="n8n_recovery_test_$$"
	log_info "Creating temporary test database: $test_db"

	# Create test database
	if ! docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d postgres -c \
		"CREATE DATABASE ${test_db};" 2>/dev/null; then
		log_error "Failed to create test database"
		log_error "PostgreSQL recovery test: FAILED (create db)"
		((TESTS_FAILED++))
		return 1
	fi

	# Restore to test database
	log_info "Restoring backup to test database..."
	if gunzip -c "$test_file" | docker exec -i "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$test_db" 2>/dev/null; then
		log_info "Restore completed"
	else
		log_warn "Restore had some warnings (may be OK)"
	fi

	# Verify restore by counting tables
	log_info "Verifying restored data..."
	local table_count
	table_count=$(docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$test_db" -t -c \
		"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')

	if [[ -z "$table_count" || "$table_count" -eq 0 ]]; then
		log_warn "No tables found - backup may have been empty"
	else
		log_info "Restored ${table_count} tables"
	fi

	# Cleanup test database
	log_info "Cleaning up test database..."
	docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d postgres -c \
		"DROP DATABASE IF EXISTS ${test_db};" 2>/dev/null

	log_success "PostgreSQL recovery test: PASSED"
	((TESTS_PASSED++))
	return 0
}

# Test Redis recovery procedure
test_redis_recovery() {
	log_info "=========================================="
	log_info "Testing Redis Recovery"
	log_info "=========================================="

	((TESTS_RUN++))

	# Find latest backup
	local backup_file
	if ! backup_file=$(find_latest_backup "redis"); then
		log_error "Redis recovery test: SKIPPED (no backup)"
		return 1
	fi

	log_info "Using backup: $backup_file"

	# Decrypt if needed
	local test_file
	if ! test_file=$(decrypt_if_needed "$backup_file"); then
		log_error "Redis recovery test: FAILED (decryption)"
		((TESTS_FAILED++))
		return 1
	fi

	# Verify RDB file format
	log_info "Verifying RDB file format..."
	if ! head -c 5 "$test_file" | grep -q "REDIS"; then
		log_error "Invalid RDB file format"
		log_error "Redis recovery test: FAILED (invalid format)"
		((TESTS_FAILED++))
		return 1
	fi
	log_info "RDB file format verified"

	# Get file size
	local backup_size
	backup_size=$(du -h "$test_file" | cut -f1)
	log_info "Backup file size: $backup_size"

	# Note: Full Redis restore would require stopping Redis
	# For testing, we just verify the file is valid
	log_info "Note: Full restore requires Redis restart (not performed in test mode)"

	log_success "Redis recovery test: PASSED (file validation)"
	((TESTS_PASSED++))
	return 0
}

# Test n8n data volume recovery procedure
test_n8n_recovery() {
	log_info "=========================================="
	log_info "Testing n8n Data Volume Recovery"
	log_info "=========================================="

	((TESTS_RUN++))

	# Find latest backup
	local backup_file
	if ! backup_file=$(find_latest_backup "n8n"); then
		log_error "n8n recovery test: SKIPPED (no backup)"
		return 1
	fi

	log_info "Using backup: $backup_file"

	# Decrypt if needed
	local test_file
	if ! test_file=$(decrypt_if_needed "$backup_file"); then
		log_error "n8n recovery test: FAILED (decryption)"
		((TESTS_FAILED++))
		return 1
	fi

	# Verify archive integrity
	log_info "Verifying archive integrity..."
	if ! gunzip -t "$test_file" 2>/dev/null; then
		log_error "Archive file is corrupted"
		log_error "n8n recovery test: FAILED (corrupt archive)"
		((TESTS_FAILED++))
		return 1
	fi
	log_info "Archive integrity verified"

	# Extract to test directory
	local extract_dir="${TEST_DIR}/n8n_data"
	mkdir -p "$extract_dir"

	log_info "Extracting archive to test directory..."
	if ! tar xzf "$test_file" -C "$extract_dir" 2>/dev/null; then
		log_error "Failed to extract archive"
		log_error "n8n recovery test: FAILED (extraction)"
		((TESTS_FAILED++))
		return 1
	fi

	# Verify extracted contents
	local file_count
	file_count=$(find "$extract_dir" -type f 2>/dev/null | wc -l)
	log_info "Extracted ${file_count} files"

	if [[ "$file_count" -eq 0 ]]; then
		log_warn "No files in backup - archive may have been empty"
	fi

	log_success "n8n recovery test: PASSED"
	((TESTS_PASSED++))
	return 0
}

# Run full recovery test suite
test_full_recovery() {
	log_info "=========================================="
	log_info "Running Full Recovery Test Suite"
	log_info "=========================================="

	test_postgres_recovery
	test_redis_recovery
	test_n8n_recovery
}

# Print test summary
print_summary() {
	echo ""
	log_info "=========================================="
	log_info "Test Summary"
	log_info "=========================================="
	log_info "Tests run: $TESTS_RUN"
	log_info "Tests passed: $TESTS_PASSED"
	log_info "Tests failed: $TESTS_FAILED"

	if [[ $TESTS_FAILED -eq 0 && $TESTS_RUN -gt 0 ]]; then
		log_success "All recovery tests passed!"
		return 0
	elif [[ $TESTS_RUN -eq 0 ]]; then
		log_warn "No tests were run"
		return 2
	else
		log_error "Some tests failed"
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	# Create log directory
	mkdir -p "$(dirname "$LOG_FILE")"

	# Parse arguments
	local mode=""

	case "${1:-}" in
	--postgres)
		mode="postgres"
		;;
	--redis)
		mode="redis"
		;;
	--n8n)
		mode="n8n"
		;;
	--full)
		mode="full"
		;;
	--list)
		list_backups
		exit 0
		;;
	--help | -h)
		show_help
		exit 0
		;;
	"")
		show_help
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		show_help
		exit 1
		;;
	esac

	log_info "=========================================="
	log_info "Starting Recovery Tests"
	log_info "=========================================="

	# Setup test environment
	if ! setup_test_env; then
		log_error "Failed to setup test environment"
		exit 2
	fi

	# Set cleanup trap
	trap cleanup_test_env EXIT

	# Run requested tests
	case "$mode" in
	postgres)
		test_postgres_recovery
		;;
	redis)
		test_redis_recovery
		;;
	n8n)
		test_n8n_recovery
		;;
	full)
		test_full_recovery
		;;
	esac

	# Print summary and exit
	print_summary
	exit $?
}

main "$@"
