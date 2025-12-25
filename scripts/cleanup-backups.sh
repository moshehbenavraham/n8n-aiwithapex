#!/bin/bash
# =============================================================================
# cleanup-backups.sh - Backup Retention Policy Enforcement
# =============================================================================
# Description: Removes backup files older than the retention period
# Usage: ./cleanup-backups.sh [--dry-run]
# Exit Codes: 0=success, 1=error
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_BASE_DIR="${PROJECT_DIR}/backups"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"

# Retention settings (in days)
RETENTION_DAYS=7

# Backup directories to clean
BACKUP_DIRS=(
    "${BACKUP_BASE_DIR}/postgres"
    "${BACKUP_BASE_DIR}/redis"
    "${BACKUP_BASE_DIR}/n8n"
    "${BACKUP_BASE_DIR}/env"
)

# File patterns to clean (excludes .gitkeep)
FILE_PATTERNS=(
    "*.sql.gz"
    "*.rdb"
    "*.tar.gz"
    "*.backup"
)

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') [cleanup-backups] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') [cleanup-backups] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') [cleanup-backups] $1" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    DRY_RUN=false
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=true
        log_info "Running in dry-run mode (no files will be deleted)"
    fi

    log_info "Starting backup cleanup (retention: ${RETENTION_DAYS} days)"

    TOTAL_DELETED=0
    TOTAL_FREED=0

    for DIR in "${BACKUP_DIRS[@]}"; do
        if [[ ! -d "$DIR" ]]; then
            log_info "Directory does not exist, skipping: ${DIR}"
            continue
        fi

        log_info "Scanning ${DIR}..."

        for PATTERN in "${FILE_PATTERNS[@]}"; do
            # Find files older than retention period
            while IFS= read -r -d '' FILE; do
                FILE_SIZE=$(du -h "$FILE" 2>/dev/null | cut -f1)
                FILE_SIZE_BYTES=$(stat -c%s "$FILE" 2>/dev/null || echo 0)

                if [[ "$DRY_RUN" == true ]]; then
                    log_info "[DRY-RUN] Would delete: ${FILE} (${FILE_SIZE})"
                else
                    if rm -f "$FILE"; then
                        log_info "Deleted: ${FILE} (${FILE_SIZE})"
                        ((TOTAL_DELETED++))
                        ((TOTAL_FREED += FILE_SIZE_BYTES))
                    else
                        log_error "Failed to delete: ${FILE}"
                    fi
                fi
            done < <(find "$DIR" -maxdepth 1 -name "$PATTERN" -type f -mtime "+${RETENTION_DAYS}" -print0 2>/dev/null)
        done
    done

    if [[ "$DRY_RUN" == true ]]; then
        log_success "Dry-run completed"
    else
        # Convert bytes to human-readable
        if [[ $TOTAL_FREED -gt 0 ]]; then
            FREED_HR=$(numfmt --to=iec-i --suffix=B "$TOTAL_FREED" 2>/dev/null || echo "${TOTAL_FREED} bytes")
        else
            FREED_HR="0B"
        fi
        log_success "Cleanup completed: ${TOTAL_DELETED} files deleted, ${FREED_HR} freed"
    fi

    exit 0
}

main "$@"
