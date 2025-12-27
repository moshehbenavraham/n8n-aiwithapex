#!/bin/bash
# =============================================================================
# backup-offsite.sh - Off-site Backup Synchronization
# =============================================================================
# Description: Syncs encrypted backup files to cloud storage using rclone
# Usage: ./backup-offsite.sh [--dry-run]
# Exit Codes: 0=success, 1=error, 2=no files to sync
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
LOCK_FILE="/tmp/n8n-offsite.lock"

# Source environment variables
if [[ -f "${PROJECT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${PROJECT_DIR}/.env"
fi

# rclone configuration from environment
REMOTE="${RCLONE_REMOTE:-n8n-backup}"
BUCKET="${RCLONE_BUCKET:-n8n-backups}"
SYNC_ENCRYPTED_ONLY="${RCLONE_SYNC_ENCRYPTED_ONLY:-true}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [backup-offsite] $1" | tee -a "$LOG_FILE"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-offsite] $1" | tee -a "$LOG_FILE"
}

log_success() {
	echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [backup-offsite] $1" | tee -a "$LOG_FILE"
}

log_warn() {
	echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') [backup-offsite] $1" | tee -a "$LOG_FILE"
}

# shellcheck disable=SC2329
cleanup_lock() {
	rm -f "$LOCK_FILE"
}

check_rclone() {
	if ! command -v rclone &>/dev/null; then
		log_error "rclone is not installed"
		log_error "Install with: curl https://rclone.org/install.sh | sudo bash"
		return 1
	fi
	return 0
}

check_remote() {
	log_info "Checking rclone remote: ${REMOTE}"
	if ! rclone listremotes 2>/dev/null | grep -q "^${REMOTE}:$"; then
		log_error "rclone remote '${REMOTE}' not configured"
		log_error "Run 'rclone config' to set up the remote"
		log_error "Or copy config/rclone.conf.example to ~/.config/rclone/rclone.conf"
		return 1
	fi

	# Test remote connectivity
	if ! rclone lsd "${REMOTE}:" --max-depth 1 &>/dev/null; then
		log_error "Cannot connect to remote '${REMOTE}'"
		log_error "Check credentials and network connectivity"
		return 1
	fi

	log_info "Remote '${REMOTE}' is accessible"
	return 0
}

count_files_to_sync() {
	local count=0

	if [[ "$SYNC_ENCRYPTED_ONLY" == "true" ]]; then
		# Count only encrypted files
		count=$(find "$BACKUP_DIR" -type f -name "*.gpg" 2>/dev/null | wc -l)
	else
		# Count all backup files
		count=$(find "$BACKUP_DIR" -type f \( -name "*.sql.gz*" -o -name "*.rdb*" -o -name "*.tar.gz*" -o -name "*.backup*" -o -name "*.yml*" \) 2>/dev/null | wc -l)
	fi

	echo "$count"
}

usage() {
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --dry-run    Show what would be synced without actually syncing"
	echo "  --help       Show this help message"
	echo ""
	echo "Environment Variables (set in .env):"
	echo "  RCLONE_REMOTE              Remote name (default: n8n-backup)"
	echo "  RCLONE_BUCKET              Bucket/container name (default: n8n-backups)"
	echo "  RCLONE_SYNC_ENCRYPTED_ONLY Sync only .gpg files (default: true)"
	echo ""
	echo "Examples:"
	echo "  $0                  # Sync encrypted backups to cloud"
	echo "  $0 --dry-run        # Preview sync without uploading"
	exit 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
	DRY_RUN=false

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--help)
			usage
			;;
		*)
			log_error "Unknown option: $1"
			usage
			;;
		esac
	done

	# Check for existing sync process
	if [[ -f "$LOCK_FILE" ]]; then
		LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
		if kill -0 "$LOCK_PID" 2>/dev/null; then
			log_error "Off-site sync already in progress (PID: ${LOCK_PID})"
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
	log_info "Starting off-site backup synchronization"
	log_info "=========================================="

	# Verify rclone is available
	if ! check_rclone; then
		exit 1
	fi

	# Verify remote is configured and accessible
	if ! check_remote; then
		exit 1
	fi

	# Check for files to sync
	FILE_COUNT=$(count_files_to_sync)
	if [[ "$FILE_COUNT" -eq 0 ]]; then
		log_warn "No backup files found to sync"
		if [[ "$SYNC_ENCRYPTED_ONLY" == "true" ]]; then
			log_info "Hint: Run backup-all.sh with BACKUP_GPG_PASSPHRASE set to create encrypted backups"
		fi
		exit 2
	fi

	log_info "Found ${FILE_COUNT} files to sync"
	log_info "Remote: ${REMOTE}:${BUCKET}"
	log_info "Sync encrypted only: ${SYNC_ENCRYPTED_ONLY}"

	# Build rclone command
	RCLONE_CMD=(rclone sync "$BACKUP_DIR" "${REMOTE}:${BUCKET}")

	# Add filter for encrypted files only
	if [[ "$SYNC_ENCRYPTED_ONLY" == "true" ]]; then
		RCLONE_CMD+=(--include "**/*.gpg")
	fi

	# Add common options
	RCLONE_CMD+=(
		--progress
		--stats 10s
		--stats-one-line
		--transfers 4
		--checkers 8
	)

	# Add dry-run if requested
	if [[ "$DRY_RUN" == true ]]; then
		RCLONE_CMD+=(--dry-run)
		log_info "DRY RUN - no files will be uploaded"
	fi

	# Execute sync
	log_info "Starting rclone sync..."
	if "${RCLONE_CMD[@]}" 2>&1 | tee -a "$LOG_FILE"; then
		if [[ "$DRY_RUN" == true ]]; then
			log_success "Dry run completed - review output above"
		else
			log_success "Off-site sync completed successfully"

			# Show remote stats
			log_info "Remote bucket contents:"
			rclone size "${REMOTE}:${BUCKET}" 2>/dev/null | while read -r line; do
				log_info "  $line"
			done
		fi
	else
		log_error "Off-site sync failed"
		exit 1
	fi

	log_info "=========================================="
	exit 0
}

main "$@"
