# Systems Administrator / Infrastructure Engineer — Test Task

## What lives where

| Path | Purpose |
|------|---------|
| `ansible/roles/backup_restic/` | Restic backup, timers, offsite copy, RPO/check |
| `ansible/roles/host_hardening/` | SSH drop-in, UFW, DOCKER-USER, daemon.json merge |
| `ansible/playbooks/backup-retention.yml` | Admin-only `forget --prune` (dual repo) |
| `scripts/ci-local.sh` | Local gate: galaxy + syntax-check + ansible-lint + shellcheck |
| `.github/workflows/validate.yml` | Workflow file (run via Actions after successful push) |
| `docs/S3_OBJECT_LOCK_AND_IAM.md` | locks/ IAM + Object Lock vs prune |
| `docker/compose.yaml` | Example app; ports via `APP_PUBLISH_IP` / `APP_PUBLISH_PORT` |

Note: `prod-backup-01` and `prod-app-01` sharing `192.168.10.15` is an **intentional lab** single-node example.

## Backup and recovery

- Restic + systemd timer (4h). Prune only from `backup_admin`.
- App IAM: DeleteObject under `locks/` only (or optional `restic_no_lock`).
- Object Lock **not** auto-configured — verify with `docs/examples/object-lock-verification.checklist.md` (UNVERIFIED).
- RTO is a **hypothesis** until `docs/examples/full-restore-timing.template.md` is filled.

Vault placeholders: `ansible/group_vars/all/vault.yml.example` (includes admin S3 keys).

## Network

```bash
APP_PORT=8080 bash scripts/network-diagnostics.sh
```

Runbook with per-hypothesis commands: `docs/NETWORK_INCIDENT_RUNBOOK.md`.

## What was verified vs not

| Item | Status |
|------|--------|
| Local CI script | Run `bash scripts/ci-local.sh`; see `docs/examples/ci-local.run.log` |
| GitHub Actions live | Only after workflow file is on remote **and** Actions enabled — do not assume live CI |
| `ansible-playbook --check` on VM | **NOT RUN** — `docs/examples/ansible-check.NOT_RUN.md` |
| Object Lock / IAM on AWS | **UNVERIFIED** checklist only |
| Full 100GB RTO | Hypothesis only |

## Validation

```bash
bash scripts/ci-local.sh
```
