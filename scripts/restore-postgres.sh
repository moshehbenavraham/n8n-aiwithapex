#!/bin/bash
# =============================================================================
# restore-postgres.sh - PostgreSQL Database Restore
# =============================================================================
# Description: Restores the n8n PostgreSQL database from a backup file
# Usage: ./restore-postgres.sh <backup_file.sql.gz>
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
CONTAINER_NAME="n8n-postgres"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${PROJECT_DIR}/.env"
else
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] .env file not found" | tee -a "$LOG_FILE"
	exit 1
fi

DB_USER="${POSTGRES_USER:-n8n}"
DB_NAME="${POSTGRES_DB:-n8n}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [restore-postgres] $1" | tee -a "$LOG_FILE"
}

check_container() {
	if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
		log_error "Container ${CONTAINER_NAME} is not running"
		return 1
	fi
	return 0
}

usage() {
	echo "Usage: $0 <backup_file.sql.gz>"
	echo ""
	echo "Arguments:"
	echo "  backup_file.sql.gz  Path to the gzip-compressed SQL backup file"
	echo ""
	echo "Example:"
	echo "  $0 backups/postgres/n8n_20250101_020000.sql.gz"
	exit 1
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	# Check arguments
	if [[ $# -ne 1 ]]; then
		usage
	fi

	BACKUP_FILE="$1"

	# Validate backup file
	if [[ ! -f "$BACKUP_FILE" ]]; then
		log_error "Backup file not found: ${BACKUP_FILE}"
		exit 1
	fi

	if [[ ! "$BACKUP_FILE" == *.sql.gz ]]; then
		log_error "Backup file must be a .sql.gz file"
		exit 1
	fi

	log_info "Starting PostgreSQL restore from: ${BACKUP_FILE}"

	# Check container is running
	if ! check_container; then
		exit 1
	fi

	# Verify backup file integrity
	log_info "Verifying backup file integrity..."
	if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
		log_error "Backup file is corrupted or not a valid gzip file"
		exit 1
	fi
	log_info "Backup file integrity verified"

	# Show warning
	log_warn "This will drop and recreate the database ${DB_NAME}"
	log_warn "All existing data will be replaced with backup data"

	# Check if running interactively
	if [[ -t 0 ]]; then
		echo ""
		read -r -p "Are you sure you want to continue? (yes/no): " CONFIRM
		if [[ "$CONFIRM" != "yes" ]]; then
			log_info "Restore cancelled by user"
			exit 0
		fi
	else
		log_info "Running non-interactively, proceeding with restore"
	fi

	# Terminate existing connections to the database
	log_info "Terminating existing database connections..."
	docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c \
		"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" \
		>/dev/null 2>&1

	# Brief pause to allow connections to fully terminate
	sleep 2

	# Drop and recreate database (using WITH FORCE for PostgreSQL 13+)
	log_info "Dropping existing database..."
	if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME} WITH (FORCE);" 2>/dev/null; then
		# Fallback for older PostgreSQL versions
		log_warn "FORCE drop failed, trying standard drop..."
		if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null; then
			log_error "Failed to drop database - active connections may be preventing drop"
			log_error "Consider stopping n8n services before restore: docker compose stop n8n n8n-worker"
			exit 1
		fi
	fi

	log_info "Creating fresh database..."
	if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null; then
		log_error "Failed to create database"
		exit 1
	fi

	# Restore from backup
	log_info "Restoring database from backup..."
	if gunzip -c "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" 2>/dev/null; then
		log_success "Database restored successfully"
	else
		log_error "Database restore failed"
		exit 1
	fi

	# Verify restore by counting tables
	log_info "Verifying restore..."
	TABLE_COUNT=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c \
		"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')

	if [[ -z "$TABLE_COUNT" || "$TABLE_COUNT" -eq 0 ]]; then
		log_warn "No tables found after restore - backup may have been empty"
	else
		log_info "Found ${TABLE_COUNT} tables in restored database"
	fi

	log_success "PostgreSQL restore completed from: ${BACKUP_FILE}"
	exit 0
}

main "$@"
