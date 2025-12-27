#!/bin/bash
# =============================================================================
# restore-redis.sh - Redis RDB Backup Restore
# =============================================================================
# Description: Restores Redis data from an RDB backup file
# Usage: ./restore-redis.sh <backup_file.rdb|backup_file.rdb.gpg>
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
CONTAINER_NAME="n8n-redis"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${PROJECT_DIR}/.env"
else
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] .env file not found" | tee -a "$LOG_FILE"
	exit 1
fi

REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_CLI="redis-cli -p ${REDIS_PORT}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [restore-redis] $1" | tee -a "$LOG_FILE"
}

# Decrypt a GPG-encrypted backup file
# Arguments: $1 = encrypted file path, $2 = output file path
# Returns: 0 on success, 1 on failure
decrypt_backup_file() {
	local encrypted_file="$1"
	local output_file="$2"

	if [[ ! -f "$encrypted_file" ]]; then
		log_error "Encrypted file not found: ${encrypted_file}"
		return 1
	fi

	# Check passphrase is set
	if [[ -z "${BACKUP_GPG_PASSPHRASE:-}" ]]; then
		log_error "BACKUP_GPG_PASSPHRASE not set - cannot decrypt backup"
		return 1
	fi

	log_info "Decrypting backup file..."
	if echo "$BACKUP_GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
		--decrypt --output "$output_file" "$encrypted_file" 2>/dev/null; then
		log_info "Backup file decrypted successfully"
		return 0
	else
		log_error "Failed to decrypt backup file - check passphrase"
		rm -f "$output_file"
		return 1
	fi
}

check_container() {
	if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
		log_error "Container ${CONTAINER_NAME} is not running"
		return 1
	fi
	return 0
}

usage() {
	echo "Usage: $0 <backup_file.rdb|backup_file.rdb.gpg>"
	echo ""
	echo "Arguments:"
	echo "  backup_file.rdb      Path to Redis RDB backup file"
	echo "  backup_file.rdb.gpg  Path to GPG-encrypted RDB backup file"
	echo ""
	echo "Examples:"
	echo "  $0 backups/redis/dump_20250101_020000.rdb"
	echo "  $0 backups/redis/dump_20250101_020000.rdb.gpg"
	echo ""
	echo "Note: For encrypted files, set BACKUP_GPG_PASSPHRASE in .env"
	echo "Warning: Redis must be stopped before restore. Services will restart."
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
	TEMP_DECRYPTED=""
	IS_ENCRYPTED=false

	# Validate backup file
	if [[ ! -f "$BACKUP_FILE" ]]; then
		log_error "Backup file not found: ${BACKUP_FILE}"
		exit 1
	fi

	# Check file extension
	if [[ "$BACKUP_FILE" == *.rdb.gpg ]]; then
		IS_ENCRYPTED=true
	elif [[ "$BACKUP_FILE" != *.rdb ]]; then
		log_error "Backup file must be .rdb or .rdb.gpg"
		exit 1
	fi

	log_info "Starting Redis restore from: ${BACKUP_FILE}"

	# Handle encrypted files
	if [[ "$IS_ENCRYPTED" == true ]]; then
		log_info "Encrypted backup detected - decrypting..."
		TEMP_DECRYPTED=$(mktemp /tmp/n8n-redis-restore-XXXXXX.rdb)
		if ! decrypt_backup_file "$BACKUP_FILE" "$TEMP_DECRYPTED"; then
			rm -f "$TEMP_DECRYPTED"
			exit 1
		fi
		BACKUP_FILE="$TEMP_DECRYPTED"
	fi

	# Cleanup function for temp file
	# shellcheck disable=SC2329
	cleanup_temp() {
		if [[ -n "$TEMP_DECRYPTED" && -f "$TEMP_DECRYPTED" ]]; then
			rm -f "$TEMP_DECRYPTED"
		fi
	}
	trap cleanup_temp EXIT

	# Check container is running
	if ! check_container; then
		exit 1
	fi

	# Verify backup file is valid RDB format (starts with REDIS magic)
	log_info "Verifying RDB file format..."
	if ! head -c 5 "$BACKUP_FILE" | grep -q "REDIS"; then
		log_error "Invalid RDB file format"
		exit 1
	fi
	log_info "RDB file format verified"

	# Show warning
	log_warn "This will replace Redis data with backup data"
	log_warn "All existing Redis data will be lost"

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

	# Get backup file size
	BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
	log_info "Backup file size: ${BACKUP_SIZE}"

	# Copy RDB file to container
	log_info "Copying RDB file to container..."
	if ! docker cp "$BACKUP_FILE" "${CONTAINER_NAME}:/data/dump.rdb.restore" 2>/dev/null; then
		log_error "Failed to copy RDB file to container"
		exit 1
	fi

	# Stop Redis to replace RDB file
	log_info "Initiating Redis shutdown for RDB replacement..."
	# shellcheck disable=SC2086
	docker exec "$CONTAINER_NAME" $REDIS_CLI SHUTDOWN NOSAVE 2>/dev/null || true

	# Wait for container to stop
	sleep 2

	# Replace the RDB file
	log_info "Replacing RDB file..."
	docker exec "$CONTAINER_NAME" sh -c "mv /data/dump.rdb.restore /data/dump.rdb" 2>/dev/null || true

	# Container should auto-restart via Docker restart policy
	log_info "Waiting for Redis to restart..."
	MAX_WAIT=30
	WAIT_COUNT=0
	while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
		if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
			# shellcheck disable=SC2086
			if docker exec "$CONTAINER_NAME" $REDIS_CLI PING 2>/dev/null | grep -q "PONG"; then
				log_info "Redis is back online"
				break
			fi
		fi
		sleep 1
		((WAIT_COUNT++))
	done

	if [[ $WAIT_COUNT -ge $MAX_WAIT ]]; then
		log_error "Redis did not restart within ${MAX_WAIT} seconds"
		log_error "Try manually: docker compose restart redis"
		exit 1
	fi

	# Verify data loaded
	log_info "Verifying restore..."
	# shellcheck disable=SC2086
	DBSIZE=$(docker exec "$CONTAINER_NAME" $REDIS_CLI DBSIZE 2>/dev/null | grep -oE '[0-9]+' || echo "0")
	log_info "Redis database size: ${DBSIZE} keys"

	log_success "Redis restore completed from: ${BACKUP_FILE}"
	exit 0
}

main "$@"
