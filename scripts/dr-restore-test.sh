#!/usr/bin/env bash
set -Eeuo pipefail

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/var/backups/restic-repo}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/etc/restic/backup.pass}"
RESTORE_TARGET="/tmp/dr-restore-test"
SOURCE_FILE="/srv/app/data/config.json"

echo "=== 1. Checking repository integrity ==="
restic check --repo "${RESTIC_REPOSITORY}" --password-file "${RESTIC_PASSWORD_FILE}"

echo "=== 2. Restoring latest snapshot ==="
rm -rf "${RESTORE_TARGET}"
mkdir -p "${RESTORE_TARGET}"

restic restore latest \
    --repo "${RESTIC_REPOSITORY}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    --target "${RESTORE_TARGET}"

RESTORED_FILE="${RESTORE_TARGET}${SOURCE_FILE}"

echo "=== 3. Validating files and checksums ==="
if [[ ! -f "${RESTORED_FILE}" ]]; then
    echo "[FAIL] Restored file ${RESTORED_FILE} not found!" >&2
    exit 1
fi

if [[ -f "${SOURCE_FILE}" ]]; then
    SRC_HASH=$(sha256sum "${SOURCE_FILE}" | awk '{print $1}')
    RST_HASH=$(sha256sum "${RESTORED_FILE}" | awk '{print $1}')
    if [[ "${SRC_HASH}" != "${RST_HASH}" ]]; then
        echo "[FAIL] Checksum mismatch!" >&2
        exit 1
    fi
    echo "[SUCCESS] SHA-256 checksums match perfectly."
fi

rm -rf "${RESTORE_TARGET}"
echo "=== DR Smoke Test passed successfully ==="
