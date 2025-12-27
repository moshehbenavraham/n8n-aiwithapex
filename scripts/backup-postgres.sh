#!/bin/bash
# =============================================================================
# backup-postgres.sh - PostgreSQL Database Backup
# =============================================================================
# Description: Creates a compressed backup of the n8n PostgreSQL database
# Usage: ./backup-postgres.sh
# Output: backups/postgres/n8n_YYYYMMDD_HHMMSS.sql.gz
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups/postgres"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
CONTAINER_NAME="n8n-postgres"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${PROJECT_DIR}/.env"
else
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-postgres] .env file not found" | tee -a "$LOG_FILE"
	exit 1
fi

# Backup settings
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/n8n_${TIMESTAMP}.sql.gz"
DB_USER="${POSTGRES_USER:-n8n}"
DB_NAME="${POSTGRES_DB:-n8n}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [backup-postgres] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-postgres] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [backup-postgres] $1" | tee -a "$LOG_FILE"
}

check_container() {
	if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
		log_error "Container ${CONTAINER_NAME} is not running"
		return 1
	fi
	return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	log_info "Starting PostgreSQL backup"

	# Check container is running
	if ! check_container; then
		exit 1
	fi

	# Ensure backup directory exists
	mkdir -p "$BACKUP_DIR"

	# Create backup with pg_dump
	log_info "Dumping database ${DB_NAME} to ${BACKUP_FILE}"

	if docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip >"$BACKUP_FILE"; then
		# Verify backup file was created and has content
		if [[ -s "$BACKUP_FILE" ]]; then
			BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
			log_success "Backup completed: ${BACKUP_FILE} (${BACKUP_SIZE})"
			exit 0
		else
			log_error "Backup file is empty"
			rm -f "$BACKUP_FILE"
			exit 1
		fi
	else
		log_error "pg_dump failed"
		rm -f "$BACKUP_FILE"
		exit 1
	fi
}

main "$@"
