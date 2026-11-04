#!/usr/bin/env bash
set -euo pipefail

export RESTIC_REPOSITORY="/var/backups/restic-repo"
export RESTIC_PASSWORD_FILE="/etc/restic/backup.pass"
BACKUP_SOURCE="/srv/app/data"
BACKUP_TAG="app-prod"
LOG_TAG="restic-backup"

log() {
    logger -t "${LOG_TAG}" "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

failure_handler() {
    local line_no=$1
    local err_code=$2
    log "CRITICAL: Backup failed on line ${line_no} with exit code${err_code}"
}
trap 'failure_handler ${LINENO}$?' ERR

log "Starting backup for ${BACKUP_SOURCE}"

restic backup \
    --tag "${BACKUP_TAG}" \
    --exclude-caches \
    --one-file-system \
    "${BACKUP_SOURCE}"

restic forget \
    --tag "${BACKUP_TAG}" \
    --keep-hourly 24 \
    --keep-daily 14 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --prune

log "Backup completed successfully."
