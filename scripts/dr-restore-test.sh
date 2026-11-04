#!/usr/bin/env bash
set -Eeuo pipefail

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/var/backups/restic-repo}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/etc/restic/backup.pass}"
RESTORE_TARGET="/tmp/dr-restore-test"
SOURCE_FILE="/srv/app/data/config.json"

echo "=== 1. Проверка метаданных репозитория (restic check) ==="
restic check --repo "${RESTIC_REPOSITORY}" --password-file "${RESTIC_PASSWORD_FILE}"

echo "=== 2. Восстановление последнего снапшота ==="
rm -rf "${RESTORE_TARGET}"
mkdir -p "${RESTORE_TARGET}"

restic restore latest \
    --repo "${RESTIC_REPOSITORY}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    --target "${RESTORE_TARGET}"

RESTORED_FILE="${RESTORE_TARGET}${SOURCE_FILE}"

echo "=== 3. Проверка наличия и сверка контрольных сумм SHA-256 ==="
if [[ ! -f "${RESTORED_FILE}" ]]; then
    echo "[FAIL] Восстановленный файл ${RESTORED_FILE} не найден!" >&2
    exit 1
fi

if [[ -f "${SOURCE_FILE}" ]]; then
    SRC_HASH=$(sha256sum "${SOURCE_FILE}" | awk '{print $1}')
    RST_HASH=$(sha256sum "${RESTORED_FILE}" | awk '{print $1}')
    
    echo "Исходный хэш:      ${SRC_HASH}"
    echo "Восстановленный:   ${RST_HASH}"
    
    if [[ "${SRC_HASH}" != "${RST_HASH}" ]]; then
        echo "[FAIL] Несовпадение контрольных сумм SHA-256!" >&2
        exit 1
    fi
    echo "[SUCCESS] Контрольные суммы SHA-256 полностью совпадают."
else
    echo "[WARN] Исходный файл отсутствует для сравнения хэшей, проверен факт восстановления."
fi

rm -rf "${RESTORE_TARGET}"
echo "=== DR Smoke Test успешно пройден ==="
