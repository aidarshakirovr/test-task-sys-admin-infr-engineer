#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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

echo "[OK] ci-local checks finished"
