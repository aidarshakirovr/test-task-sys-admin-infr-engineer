#!/usr/bin/env bash
set -Eeuo pipefail

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/var/backups/restic-repo}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/etc/restic/backup.pass}"
RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/var/cache/restic-backup}"
BACKUP_SOURCE="${BACKUP_SOURCE:-/srv/app/data}"

export RESTIC_CACHE_DIR

failure_handler() {
    local lineno="$1"
    local exit_code="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Backup failed at line ${lineno} with exit status ${exit_code}." >&2
    exit "${exit_code}"
}

trap 'failure_handler "$LINENO" "$?"' ERR

echo "[INFO] Starting restic backup of ${BACKUP_SOURCE}..."
restic backup \
    --repo "${RESTIC_REPOSITORY}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    --tag "app-data" \
    "${BACKUP_SOURCE}"

echo "[INFO] Applying retention policy..."
restic forget \
    --repo "${RESTIC_REPOSITORY}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    --keep-hourly 24 \
    --keep-daily 14 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --prune

echo "[INFO] Backup completed successfully."
