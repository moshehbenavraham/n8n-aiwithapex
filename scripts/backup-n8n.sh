#!/bin/bash
# =============================================================================
# backup-n8n.sh - n8n Data Volume Backup
# =============================================================================
# Description: Creates a compressed backup of the n8n data volume
# Usage: ./backup-n8n.sh
# Output: backups/n8n/n8n_data_YYYYMMDD_HHMMSS.tar.gz
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups/n8n"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
VOLUME_NAME="n8n_n8n_data"

# Backup settings
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILENAME="n8n_data_${TIMESTAMP}.tar.gz"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILENAME}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [backup-n8n] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [backup-n8n] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [backup-n8n] $1" | tee -a "$LOG_FILE"
}

check_volume() {
    if ! docker volume inspect "$VOLUME_NAME" &>/dev/null; then
        log_error "Docker volume ${VOLUME_NAME} does not exist"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "Starting n8n data backup"

    # Check volume exists
    if ! check_volume; then
        exit 1
    fi

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"

    # Create backup using alpine container with volume mount
    log_info "Creating archive ${BACKUP_FILE}"

    if docker run --rm \
        -v "${VOLUME_NAME}:/data:ro" \
        -v "${BACKUP_DIR}:/backup" \
        alpine:latest \
        tar czf "/backup/${BACKUP_FILENAME}" -C /data .; then

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
        log_error "tar backup failed"
        rm -f "$BACKUP_FILE"
        exit 1
    fi
}

main "$@"
