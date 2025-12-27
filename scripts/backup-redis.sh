#!/bin/bash
# =============================================================================
# backup-redis.sh - Redis RDB Snapshot Backup
# =============================================================================
# Description: Creates a backup of the Redis RDB snapshot file
# Usage: ./backup-redis.sh
# Output: backups/redis/dump_YYYYMMDD_HHMMSS.rdb
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups/redis"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
CONTAINER_NAME="n8n-redis"

# Source environment variables for Redis port
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${PROJECT_DIR}/.env"
fi

# Redis settings
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_CLI="redis-cli -p ${REDIS_PORT}"

# Backup settings
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/dump_${TIMESTAMP}.rdb"
MAX_WAIT_SECONDS=60

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [backup-redis] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-redis] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [backup-redis] $1" | tee -a "$LOG_FILE"
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
	log_info "Starting Redis backup"

	# Check container is running
	if ! check_container; then
		exit 1
	fi

	# Ensure backup directory exists
	mkdir -p "$BACKUP_DIR"

	# Get current LASTSAVE timestamp before BGSAVE
	# shellcheck disable=SC2086
	LAST_SAVE=$(docker exec "$CONTAINER_NAME" $REDIS_CLI LASTSAVE 2>/dev/null)
	if [[ -z "$LAST_SAVE" ]]; then
		log_error "Failed to get LASTSAVE from Redis (port ${REDIS_PORT})"
		exit 1
	fi
	log_info "Current LASTSAVE: ${LAST_SAVE}"

	# Trigger background save
	log_info "Triggering BGSAVE"
	# shellcheck disable=SC2086
	BGSAVE_RESULT=$(docker exec "$CONTAINER_NAME" $REDIS_CLI BGSAVE 2>/dev/null)
	if [[ "$BGSAVE_RESULT" != *"started"* && "$BGSAVE_RESULT" != *"scheduled"* ]]; then
		log_error "BGSAVE failed: ${BGSAVE_RESULT}"
		exit 1
	fi

	# Wait for BGSAVE to complete
	log_info "Waiting for BGSAVE to complete..."
	WAIT_COUNT=0
	while [[ $WAIT_COUNT -lt $MAX_WAIT_SECONDS ]]; do
		# shellcheck disable=SC2086
		CURRENT_SAVE=$(docker exec "$CONTAINER_NAME" $REDIS_CLI LASTSAVE 2>/dev/null)
		if [[ "$CURRENT_SAVE" != "$LAST_SAVE" ]]; then
			log_info "BGSAVE completed. New LASTSAVE: ${CURRENT_SAVE}"
			break
		fi
		sleep 1
		((WAIT_COUNT++))
	done

	if [[ $WAIT_COUNT -ge $MAX_WAIT_SECONDS ]]; then
		log_error "BGSAVE timeout after ${MAX_WAIT_SECONDS} seconds"
		exit 1
	fi

	# Copy RDB file from container
	log_info "Copying RDB file to ${BACKUP_FILE}"
	if docker cp "${CONTAINER_NAME}:/data/dump.rdb" "$BACKUP_FILE" 2>/dev/null; then
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
		log_error "Failed to copy RDB file from container"
		exit 1
	fi
}

main "$@"
