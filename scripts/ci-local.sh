#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Prepend common user-local Python Scripts dirs (Windows pip --user / Git bash).
# Example: /c/Users/Aidar/AppData/Roaming/Python/Python314/Scripts
_win_user="${USERNAME:-${USER:-}}"
_candidates=(
  "${HOME}/AppData/Roaming/Python/Python314/Scripts"
  "${HOME}/AppData/Roaming/Python/Python313/Scripts"
  "${HOME}/AppData/Roaming/Python/Python312/Scripts"
  "${HOME}/.local/bin"
)
if [[ -n "${_win_user}" ]]; then
  _candidates+=(
    "/c/Users/${_win_user}/AppData/Roaming/Python/Python314/Scripts"
    "/c/Users/${_win_user}/AppData/Roaming/Python/Python313/Scripts"
    "/c/Users/${_win_user}/AppData/Roaming/Python/Python312/Scripts"
  )
fi
if [[ -n "${USERPROFILE:-}" ]]; then
  _up="$(cygpath -u "${USERPROFILE}" 2>/dev/null || true)"
  if [[ -n "${_up}" ]]; then
    _candidates+=(
      "${_up}/AppData/Roaming/Python/Python314/Scripts"
      "${_up}/AppData/Roaming/Python/Python313/Scripts"
      "${_up}/AppData/Roaming/Python/Python312/Scripts"
    )
  fi
fi
for _d in "${_candidates[@]}"; do
  if [[ -d "${_d}" ]]; then
    PATH="${_d}:${PATH}"
  fi
done
export PATH
unset _d _candidates _win_user _up

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "[ERROR] ansible-playbook not found on PATH=${PATH}" >&2
  echo "Install: python -m pip install --user 'ansible-core>=2.16' ansible-lint" >&2
  echo "Then: export PATH=\"/c/Users/\$USER/AppData/Roaming/Python/Python314/Scripts:\$PATH\"" >&2
  exit 127
fi

echo "== tools =="
command -v ansible-galaxy
command -v ansible-playbook
command -v ansible-lint || echo "[WARN] ansible-lint missing"

echo "== galaxy =="
ansible-galaxy collection install -r ansible/requirements.yml

echo "== syntax-check =="
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/site.yml --syntax-check
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/playbooks/backup-retention.yml --syntax-check

echo "== ansible-lint =="
if command -v ansible-lint >/dev/null 2>&1; then
  ansible-lint -c .ansible-lint ansible/site.yml ansible/playbooks/backup-retention.yml ansible/roles/*
else
  echo "[WARN] ansible-lint not installed"
fi

echo "== shell scripts =="
bash -n scripts/*.sh
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh
else
  echo "[WARN] shellcheck not installed; bash -n only"
fi

echo "== tests/smoke.yml present =="
test -f tests/smoke.yml

echo "[OK] ci-local checks finished"
