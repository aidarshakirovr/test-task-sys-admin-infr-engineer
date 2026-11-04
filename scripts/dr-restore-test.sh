#!/usr/bin/env bash
set -Eeuo pipefail

REPO_PATH="${RESTIC_REPOSITORY:-/var/backups/restic-repo}"
PASS_FILE="${RESTIC_PASSWORD_FILE:-/etc/restic/backup.pass}"
SOURCE_DIR="${BACKUP_SOURCE_DIR:-/srv/app/data}"
RESTORE_TARGET="/tmp/dr-verify-$$"

cleanup() {
    rm -rf "${RESTORE_TARGET}"
}
trap cleanup EXIT

echo "=== [DR-TEST] 1. Проверка окружения и тестовых данных ==="
mkdir -p "${SOURCE_DIR}" "$(dirname "${PASS_FILE}")" "$(dirname "${REPO_PATH}")"
if [[ ! -f "${PASS_FILE}" ]]; then
    echo "temporary-dr-test-pass" > "${PASS_FILE}"
    chmod 0600 "${PASS_FILE}"
fi

if [[ ! -f "${SOURCE_DIR}/dr_probe.txt" ]]; then
    echo "DR Verification Probe Data - $(date)" > "${SOURCE_DIR}/dr_probe.txt"
fi

if [[ ! -f "${REPO_PATH}/config" ]]; then
    echo "[INFO] Инициализация локального репозитория Restic..."
    restic -r "${REPO_PATH}" --password-file "${PASS_FILE}" init
fi

restic -r "${REPO_PATH}" --password-file "${PASS_FILE}" backup "${SOURCE_DIR}" --quiet

echo "=== [DR-TEST] 2. Проверка целостности репозитория (restic check) ==="
restic -r "${REPO_PATH}" --password-file "${PASS_FILE}" check --read-data-subset=10%

echo "=== [DR-TEST] 3. Тестовое восстановление последнего снапшота в ${RESTORE_TARGET} ==="
mkdir -p "${RESTORE_TARGET}"
restic -r "${REPO_PATH}" --password-file "${PASS_FILE}" restore latest --target "${RESTORE_TARGET}"

echo "=== [DR-TEST] 4. Побайтовая сверка контрольных сумм SHA-256 ==="
# Сверяем строго файлы внутри восстановленной структуры исходного каталога
RESTORED_PATH="${RESTORE_TARGET}${SOURCE_DIR}"

ORIG_SUM=$(find "${SOURCE_DIR}" -type f -exec sha256sum {} + | sort | sha256sum | awk '{print $1}')
REST_SUM=$(find "${RESTORED_PATH}" -type f -exec sha256sum {} + | sort | sha256sum | awk '{print $1}')

echo "Хэш исходных данных:       ${ORIG_SUM}"
echo "Хэш восстановленных данных: ${REST_SUM}"

if [[ "${ORIG_SUM}" == "${REST_SUM}" ]]; then
    echo "[SUCCESS] DR-тест успешно пройден: 100% совпадение контрольных сумм SHA-256."
else
    echo "[ERROR] Нарушение целостности данных при восстановлении!"
    exit 1
fi
