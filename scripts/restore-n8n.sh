#!/bin/bash
# =============================================================================
# restore-n8n.sh - n8n Data Volume Restore
# =============================================================================
# Description: Restores n8n data volume from a tar.gz backup
# Usage: ./restore-n8n.sh <backup_file.tar.gz|backup_file.tar.gz.gpg>
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
VOLUME_NAME="n8n_n8n_data"
N8N_CONTAINER="n8n-main"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${PROJECT_DIR}/.env"
else
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] .env file not found" | tee -a "$LOG_FILE"
	exit 1
fi

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [restore-n8n] $1" | tee -a "$LOG_FILE"
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

check_volume() {
	if ! docker volume inspect "$VOLUME_NAME" &>/dev/null; then
		log_error "Docker volume ${VOLUME_NAME} does not exist"
		return 1
	fi
	return 0
}

usage() {
	echo "Usage: $0 <backup_file.tar.gz|backup_file.tar.gz.gpg>"
	echo ""
	echo "Arguments:"
	echo "  backup_file.tar.gz      Path to n8n data backup archive"
	echo "  backup_file.tar.gz.gpg  Path to GPG-encrypted backup archive"
	echo ""
	echo "Examples:"
	echo "  $0 backups/n8n/n8n_data_20250101_020000.tar.gz"
	echo "  $0 backups/n8n/n8n_data_20250101_020000.tar.gz.gpg"
	echo ""
	echo "Note: For encrypted files, set BACKUP_GPG_PASSPHRASE in .env"
	echo "Warning: n8n services should be stopped before restore."
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
	if [[ "$BACKUP_FILE" == *.tar.gz.gpg ]]; then
		IS_ENCRYPTED=true
	elif [[ "$BACKUP_FILE" != *.tar.gz ]]; then
		log_error "Backup file must be .tar.gz or .tar.gz.gpg"
		exit 1
	fi

	log_info "Starting n8n data restore from: ${BACKUP_FILE}"

	# Handle encrypted files
	if [[ "$IS_ENCRYPTED" == true ]]; then
		log_info "Encrypted backup detected - decrypting..."
		TEMP_DECRYPTED=$(mktemp /tmp/n8n-data-restore-XXXXXX.tar.gz)
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

	# Check volume exists
	if ! check_volume; then
		exit 1
	fi

	# Verify backup file integrity
	log_info "Verifying backup file integrity..."
	if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
		log_error "Backup file is corrupted or not a valid gzip file"
		exit 1
	fi
	log_info "Backup file integrity verified"

	# Get backup file size
	BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
	log_info "Backup file size: ${BACKUP_SIZE}"

	# Show warning
	log_warn "This will replace n8n data volume with backup data"
	log_warn "All existing n8n files (credentials, workflows, etc.) will be replaced"

	# Check if n8n container is running
	if docker ps --format '{{.Names}}' | grep -q "^${N8N_CONTAINER}$"; then
		log_warn "n8n container is running - recommend stopping first"
		log_warn "Run: docker compose stop n8n n8n-worker"
	fi

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

	# Create backup of current data before overwriting
	log_info "Creating safety backup of current data..."
	SAFETY_BACKUP="/tmp/n8n_data_prerestore_$(date '+%Y%m%d_%H%M%S').tar.gz"
	if docker run --rm \
		-v "${VOLUME_NAME}:/data:ro" \
		-v "/tmp:/backup" \
		alpine:latest \
		tar czf "/backup/$(basename "$SAFETY_BACKUP")" -C /data . 2>/dev/null; then
		log_info "Safety backup created: ${SAFETY_BACKUP}"
	else
		log_warn "Could not create safety backup - continuing anyway"
	fi

	# Clear existing volume data
	log_info "Clearing existing volume data..."
	if ! docker run --rm \
		-v "${VOLUME_NAME}:/data" \
		alpine:latest \
		sh -c "rm -rf /data/* /data/.[!.]* 2>/dev/null || true"; then
		log_error "Failed to clear volume data"
		exit 1
	fi

	# Restore from backup
	log_info "Restoring data from backup..."
	BACKUP_DIR=$(dirname "$BACKUP_FILE")
	BACKUP_FILENAME=$(basename "$BACKUP_FILE")

	if docker run --rm \
		-v "${VOLUME_NAME}:/data" \
		-v "${BACKUP_DIR}:/backup:ro" \
		alpine:latest \
		tar xzf "/backup/${BACKUP_FILENAME}" -C /data; then
		log_info "Data extraction completed"
	else
		log_error "Failed to extract backup"
		log_error "Safety backup available at: ${SAFETY_BACKUP}"
		exit 1
	fi

	# Verify restore by listing contents
	log_info "Verifying restore..."
	FILE_COUNT=$(docker run --rm \
		-v "${VOLUME_NAME}:/data:ro" \
		alpine:latest \
		find /data -type f 2>/dev/null | wc -l)
	log_info "Restored ${FILE_COUNT} files to volume"

	# Clean up safety backup on success
	if [[ -f "$SAFETY_BACKUP" ]]; then
		rm -f "$SAFETY_BACKUP"
		log_info "Removed safety backup"
	fi

	log_success "n8n data restore completed from: ${BACKUP_FILE}"
	log_info "Restart n8n services: docker compose up -d n8n n8n-worker"
	exit 0
}

main "$@"
