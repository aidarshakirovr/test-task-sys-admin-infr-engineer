#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only verification of an EXISTING Restic repository (local or remote).
# Does not initialize repositories, create source files, or restore over production data.

REPO_PATH="${RESTIC_REPOSITORY:-/var/backups/restic-repo}"
PASS_FILE="${RESTIC_PASSWORD_FILE:-/etc/restic/backup.pass}"
SOURCE_DIR="${BACKUP_SOURCE_DIR:-/srv/app/data}"
SAMPLE_FILES="${DR_SAMPLE_FILES:-20}"
RESTORE_BASE="${DR_RESTORE_BASE:-/var/tmp}"
SMOKE_CMD="${DR_SMOKE_CMD:-}"

fail() { echo "[ERROR] $*" >&2; exit 1; }

command -v restic >/dev/null 2>&1 || fail "restic is not installed"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is not installed"
command -v python3 >/dev/null 2>&1 || fail "python3 is not installed"
[[ -d "$SOURCE_DIR" ]] || fail "Source directory does not exist: $SOURCE_DIR"
[[ -f "$PASS_FILE" ]] || fail "Password file does not exist: $PASS_FILE"
[[ -r "$PASS_FILE" ]] || fail "Password file is not readable: $PASS_FILE"
[[ "$SAMPLE_FILES" =~ ^[1-9][0-9]*$ ]] || fail "DR_SAMPLE_FILES must be a positive integer"

# Local path repos must exist; s3:/rest: backends are probed via restic itself.
if [[ "$REPO_PATH" == /* ]]; then
  [[ -d "$REPO_PATH" && -f "$REPO_PATH/config" ]] || fail "Existing local repository not found: $REPO_PATH"
fi

export RESTIC_REPOSITORY="$REPO_PATH"
export RESTIC_PASSWORD_FILE="$PASS_FILE"

RESTORE_TARGET="$(mktemp -d "${RESTORE_BASE%/}/restic-dr-verify.XXXXXX")"
cleanup() { rm -rf -- "$RESTORE_TARGET"; }
trap cleanup EXIT

START_EPOCH="$(date +%s)"
echo "=== 0. Timing start: $(date -Is) ==="

echo "=== 1. Repository snapshot availability ==="
restic snapshots --latest 1

echo "=== 2. Repository integrity check (10% data subset) ==="
restic check --read-data-subset=10%

echo "=== 3. Select up to ${SAMPLE_FILES} RANDOM existing files ==="
mapfile -d '' -t SELECTED_FILES < <(
  find "$SOURCE_DIR" -type f -print0 | python3 -c '
import random, sys
n = int(sys.argv[1])
files = [f for f in sys.stdin.buffer.read().split(b"\0") if f]
random.shuffle(files)
chosen = files[:n]
if chosen:
    sys.stdout.buffer.write(b"\0".join(chosen) + b"\0")
' "$SAMPLE_FILES"
)
((${#SELECTED_FILES[@]} > 0)) || fail "No regular files found under $SOURCE_DIR"

INCLUDE_ARGS=()
for file in "${SELECTED_FILES[@]}"; do
  INCLUDE_ARGS+=(--include "$file")
done

echo "=== 4. Restore selected files into an isolated temporary directory ==="
restic restore latest --target "$RESTORE_TARGET" "${INCLUDE_ARGS[@]}"

echo "=== 5. Compare SHA-256 checksums ==="
RESTORED_SOURCE="${RESTORE_TARGET}${SOURCE_DIR}"
[[ -d "$RESTORED_SOURCE" ]] || fail "Expected restored path not found: $RESTORED_SOURCE"

for original in "${SELECTED_FILES[@]}"; do
  relative="${original#"$SOURCE_DIR"/}"
  restored="${RESTORED_SOURCE}/${relative}"
  [[ -f "$restored" ]] || fail "Missing restored file: $relative"
  original_hash="$(sha256sum -- "$original" | awk '{print $1}')"
  restored_hash="$(sha256sum -- "$restored" | awk '{print $1}')"
  [[ "$original_hash" == "$restored_hash" ]] || fail "Checksum mismatch: $relative"
  printf '[OK] %s\n' "$relative"
done

if [[ -n "$SMOKE_CMD" ]]; then
  echo "=== 6. Optional application smoke test ==="
  bash -c "$SMOKE_CMD"
fi

END_EPOCH="$(date +%s)"
ELAPSED="$((END_EPOCH - START_EPOCH))"
echo "[SUCCESS] DR sample restore passed (${#SELECTED_FILES[@]} files) in ${ELAPSED}s."
echo "[INFO] This is not a full 100GB restore timing; record a quarterly full restore separately."
