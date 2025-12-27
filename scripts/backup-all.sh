#!/bin/bash
# =============================================================================
# backup-all.sh - Master Backup Orchestrator
# =============================================================================
# Description: Runs all backup scripts in sequence with logging and error handling
# Usage: ./backup-all.sh
# Exit Codes: 0=all backups successful, 1=one or more backups failed
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
LOCK_FILE="/tmp/n8n-backup.lock"

# Minimum disk space required (in KB) - 1GB
MIN_DISK_SPACE_KB=1048576

# Backup scripts to execute (in order)
BACKUP_SCRIPTS=(
	"${SCRIPT_DIR}/cleanup-backups.sh"
	"${SCRIPT_DIR}/backup-postgres.sh"
	"${SCRIPT_DIR}/backup-redis.sh"
	"${SCRIPT_DIR}/backup-n8n.sh"
)

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [backup-all] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-all] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [backup-all] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [backup-all] $1" | tee -a "$LOG_FILE"
}

# shellcheck disable=SC2329
cleanup_lock() {
	rm -f "$LOCK_FILE"
}

check_disk_space() {
	AVAILABLE_KB=$(df -k "$BACKUP_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
	if [[ -z "$AVAILABLE_KB" ]]; then
		log_warn "Could not determine available disk space"
		return 0
	fi

	if [[ $AVAILABLE_KB -lt $MIN_DISK_SPACE_KB ]]; then
		AVAILABLE_HR=$(numfmt --from=iec --to=iec-i "${AVAILABLE_KB}K" 2>/dev/null || echo "${AVAILABLE_KB}KB")
		log_error "Insufficient disk space: ${AVAILABLE_HR} available, 1GiB required"
		return 1
	fi

	AVAILABLE_HR=$(numfmt --from=iec --to=iec-i "${AVAILABLE_KB}K" 2>/dev/null || echo "${AVAILABLE_KB}KB")
	log_info "Disk space check passed: ${AVAILABLE_HR} available"
	return 0
}

backup_env_file() {
	log_info "Backing up environment file"

	ENV_FILE="${PROJECT_DIR}/.env"
	ENV_BACKUP_DIR="${BACKUP_DIR}/env"
	TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
	ENV_BACKUP_FILE="${ENV_BACKUP_DIR}/env_${TIMESTAMP}.backup"

	if [[ ! -f "$ENV_FILE" ]]; then
		log_error ".env file not found at ${ENV_FILE}"
		return 1
	fi

	mkdir -p "$ENV_BACKUP_DIR"

	if cp "$ENV_FILE" "$ENV_BACKUP_FILE"; then
		# Set restrictive permissions (owner read/write only)
		chmod 600 "$ENV_BACKUP_FILE"
		BACKUP_SIZE=$(du -h "$ENV_BACKUP_FILE" | cut -f1)
		log_success "Environment backup completed: ${ENV_BACKUP_FILE} (${BACKUP_SIZE})"
		return 0
	else
		log_error "Failed to backup environment file"
		return 1
	fi
}

backup_ngrok_config() {
	log_info "Backing up ngrok configuration"

	NGROK_CONFIG="${PROJECT_DIR}/config/ngrok.yml"
	NGROK_BACKUP_DIR="${BACKUP_DIR}/ngrok"
	TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
	NGROK_BACKUP_FILE="${NGROK_BACKUP_DIR}/ngrok_${TIMESTAMP}.yml"

	if [[ ! -f "$NGROK_CONFIG" ]]; then
		log_warn "ngrok.yml not found at ${NGROK_CONFIG} - skipping"
		return 0
	fi

	mkdir -p "$NGROK_BACKUP_DIR"

	if cp "$NGROK_CONFIG" "$NGROK_BACKUP_FILE"; then
		BACKUP_SIZE=$(du -h "$NGROK_BACKUP_FILE" | cut -f1)
		log_success "ngrok config backup completed: ${NGROK_BACKUP_FILE} (${BACKUP_SIZE})"
		return 0
	else
		log_error "Failed to backup ngrok configuration"
		return 1
	fi
}

# -----------------------------------------------------------------------------
# Encryption Functions (Phase 03)
# -----------------------------------------------------------------------------

# Encrypt a single backup file using GPG symmetric encryption
# Arguments: $1 = file path to encrypt
# Returns: 0 on success, 1 on failure
encrypt_backup_file() {
	local file="$1"
	local encrypted_file="${file}.gpg"

	if [[ ! -f "$file" ]]; then
		log_error "Cannot encrypt: file not found: ${file}"
		return 1
	fi

	# Skip if already encrypted
	if [[ "$file" == *.gpg ]]; then
		log_warn "File already encrypted: ${file}"
		return 0
	fi

	# Encrypt using GPG symmetric encryption with AES-256
	if echo "$BACKUP_GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
		--symmetric --cipher-algo AES256 \
		--output "$encrypted_file" "$file" 2>/dev/null; then
		local orig_size
		local enc_size
		orig_size=$(du -h "$file" | cut -f1)
		enc_size=$(du -h "$encrypted_file" | cut -f1)
		log_info "Encrypted: $(basename "$file") (${orig_size} -> ${enc_size})"
		return 0
	else
		log_error "Failed to encrypt: ${file}"
		rm -f "$encrypted_file"
		return 1
	fi
}

# Encrypt all recent backup files in the backup directory
# Only encrypts files created in the last hour (to avoid re-encrypting old backups)
encrypt_backups() {
	# Check if encryption is enabled
	if [[ -z "${BACKUP_GPG_PASSPHRASE:-}" ]]; then
		log_warn "BACKUP_GPG_PASSPHRASE not set - skipping encryption"
		return 0
	fi

	# Check passphrase minimum length (16 chars recommended)
	if [[ ${#BACKUP_GPG_PASSPHRASE} -lt 16 ]]; then
		log_warn "BACKUP_GPG_PASSPHRASE is short (< 16 chars) - consider using a stronger passphrase"
	fi

	# Verify GPG is available
	if ! command -v gpg &>/dev/null; then
		log_error "GPG not installed - cannot encrypt backups"
		return 1
	fi

	log_info "Starting backup encryption"

	local encrypted_count=0
	local failed_count=0

	# Find backup files created in the last 60 minutes (excludes .gpg files)
	while IFS= read -r -d '' file; do
		if encrypt_backup_file "$file"; then
			((encrypted_count++))
		else
			((failed_count++))
		fi
	done < <(find "$BACKUP_DIR" -type f \( -name "*.sql.gz" -o -name "*.rdb" -o -name "*.tar.gz" -o -name "*.backup" -o -name "*.yml" \) -mmin -60 ! -name "*.gpg" -print0 2>/dev/null)

	if [[ $encrypted_count -eq 0 && $failed_count -eq 0 ]]; then
		log_info "No new backup files to encrypt"
	elif [[ $failed_count -eq 0 ]]; then
		log_success "Encrypted ${encrypted_count} backup file(s)"
	else
		log_warn "Encrypted ${encrypted_count} file(s), ${failed_count} failed"
		return 1
	fi

	return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	# Source environment variables for encryption passphrase
	if [[ -f "${PROJECT_DIR}/.env" ]]; then
		# shellcheck source=/dev/null
		source "${PROJECT_DIR}/.env"
	fi

	# Check for existing backup process
	if [[ -f "$LOCK_FILE" ]]; then
		LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
		if kill -0 "$LOCK_PID" 2>/dev/null; then
			log_error "Backup already in progress (PID: ${LOCK_PID})"
			exit 1
		else
			log_warn "Stale lock file found, removing"
			rm -f "$LOCK_FILE"
		fi
	fi

	# Create lock file
	echo $$ >"$LOCK_FILE"
	trap cleanup_lock EXIT

	log_info "=========================================="
	log_info "Starting full backup process"
	log_info "=========================================="

	# Check disk space before starting
	if ! check_disk_space; then
		exit 1
	fi

	FAILED=0
	SUCCEEDED=0
	TOTAL=${#BACKUP_SCRIPTS[@]}

	# Run each backup script
	for SCRIPT in "${BACKUP_SCRIPTS[@]}"; do
		SCRIPT_NAME=$(basename "$SCRIPT")
		log_info "Running: ${SCRIPT_NAME}"

		if [[ ! -x "$SCRIPT" ]]; then
			log_error "Script not executable: ${SCRIPT_NAME}"
			((FAILED++))
			continue
		fi

		if "$SCRIPT"; then
			((SUCCEEDED++))
		else
			log_error "${SCRIPT_NAME} failed with exit code $?"
			((FAILED++))
		fi
	done

	# Backup environment file
	log_info "Running: env file backup"
	if backup_env_file; then
		((SUCCEEDED++))
	else
		((FAILED++))
	fi
	((TOTAL++))

	# Backup ngrok configuration
	log_info "Running: ngrok config backup"
	if backup_ngrok_config; then
		((SUCCEEDED++))
	else
		((FAILED++))
	fi
	((TOTAL++))

	# Encrypt all backup files if passphrase is configured
	log_info "Running: backup encryption"
	if encrypt_backups; then
		((SUCCEEDED++))
	else
		((FAILED++))
	fi
	((TOTAL++))

	log_info "=========================================="
	if [[ $FAILED -eq 0 ]]; then
		log_success "All backups completed successfully (${SUCCEEDED}/${TOTAL})"
		exit 0
	else
		log_error "Backup completed with errors: ${SUCCEEDED}/${TOTAL} succeeded, ${FAILED} failed"
		exit 1
	fi
}

main "$@"
