#!/usr/bin/env bash
set -euo pipefail

RESTIC_REPO="/var/backups/restic-repo"
PASS_FILE="/etc/restic/backup.pass"
TEST_RESTORE_DIR="/tmp/dr-test-restore"

echo "[DR-TEST] 1. Checking repository integrity..."
restic -r "${RESTIC_REPO}" --password-file "${PASS_FILE}" check

echo "[DR-TEST] 2. Restoring latest snapshot..."
rm -rf "${TEST_RESTORE_DIR}"
mkdir -p "${TEST_RESTORE_DIR}"

restic -r "${RESTIC_REPO}" --password-file "${PASS_FILE}" restore latest \
    --tag app-prod \
    --target "${TEST_RESTORE_DIR}"

echo "[DR-TEST] 3. Validating restored files..."
if [ -f "${TEST_RESTORE_DIR}/srv/app/data/config.json" ]; then
    echo "[DR-TEST] SUCCESS: Essential files restored and verified."
    rm -rf "${TEST_RESTORE_DIR}"
    exit 0
else
    echo "[DR-TEST] CRITICAL ERROR: Restored structure is corrupted!"
    exit 1
fi
