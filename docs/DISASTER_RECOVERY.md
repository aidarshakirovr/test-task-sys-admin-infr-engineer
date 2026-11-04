# Disaster Recovery Plan

## 1. Scope and recovery objectives

- Protected path: `/srv/app/data` (estimated ~100 GB; measure actual used bytes with `du -sh`).
- Backup interval: every 4 hours via systemd timer (`restic_schedule`).
- Target RPO: ≤ 4 hours, enforced by `app-backup-rpo.timer` (age of latest snapshot) plus backup failure alerts (`OnFailure=` / Healthchecks).
- Target RTO (**hypothesis until measured**): for ~100 GB over a 1 Gbit/s path, naive wall-clock is on the order of 15–25 minutes plus verification; over 100 Mbit/s, closer to 2.5–4 hours. Treat any number as a hypothesis until a full restore is timed on representative hardware and the result is recorded.

Restic provides encrypted, deduplicated snapshots. No separate tar/zip layer is required for space savings.

## 2. Consistency before backup

If `/srv/app/data` contains a database (PostgreSQL, MySQL/MariaDB, MongoDB, etc.):

1. Take an application-consistent dump **or** a filesystem/LVM/ZFS snapshot first.
2. Point Restic at the dump/snapshot mount (or quiesce writes briefly).
3. Document the chosen method in the host's runbook.

A plain file-level backup of live DB files can restore a crash-consistent tree only; that may be insufficient for production RPO/RTO claims.

## 3. Storage, offsite copy, ransomware protection

- Primary repository: local and/or S3 (`restic_backend`).
- Offsite: enable `restic_copy_enabled` so each backup runs `restic copy` into `restic_secondary_repo_path`. Production asserts require copy + distinct secondary password.
- App-host IAM: allow `DeleteObject` **only under `locks/`** (restic lock release). Deny delete on data keys. See `docs/S3_OBJECT_LOCK_AND_IAM.md`. Optional `restic_no_lock` (default false) if locks/ delete is impossible — risky.
- `forget --prune` only from `backup_admin` with delete-capable keys (`ansible/playbooks/backup-retention.yml`).
- **Object Lock is NOT configured by this role.** Compliance mode blocks prune of locked objects; use Governance, lifecycle expiry, or accept delayed prune. Verify manually before claiming immutability.

A local repo on the app host alone is **not** ransomware-resistant.

Full restore timing template: `docs/examples/full-restore-timing.template.md` (RTO stays a hypothesis until filled).

## 4. Restore runbooks

### Selected files to staging

```bash
sudo install -d -m 0750 /var/tmp/recovery
sudo -u restic-backup restic \
  -r "$RESTIC_REPOSITORY" \
  --password-file /etc/restic/backup.pass \
  restore latest --target /var/tmp/recovery \
  --include /srv/app/data/config.json
```

Review ownership, permissions, and content before any production cutover.

### Full host recovery

1. Provision a clean host; install packages.
2. Restore Ansible + Vault secrets from the approved secure source.
3. Install the same Restic major/minor as backup hosts.
4. Access the **offsite** repository; verify credentials.
5. `restic snapshots` and `restic check`.
6. Restore to a staging volume with enough free space.
7. Verify checksums, permissions, DB import if applicable, application smoke test.
8. Switch traffic only after validation.

## 5. DR verification plan

Sample test (random files, timing, optional smoke):

```bash
sudo -u restic-backup \
  RESTIC_REPOSITORY=/var/backups/restic-repo \
  RESTIC_PASSWORD_FILE=/etc/restic/backup.pass \
  BACKUP_SOURCE_DIR=/srv/app/data \
  DR_SMOKE_CMD='cd "$RESTORE_TARGET/srv/app/data" && python3 -m http.server 18080 & sleep 1; curl -fsS http://127.0.0.1:18080/ >/dev/null' \
  bash scripts/dr-restore-test.sh
```

Smoke must hit **restored/staging** paths (or a staging host), not live production `:8080`.  
Optional: `DR_READ_DATA_SUBSET=100%` and `DR_CHECK_OWNERSHIP=1`.

For S3/offsite, export `RESTIC_REPOSITORY=s3:...` and load AWS env (`/etc/restic/aws.env`).

Quarterly: full 100 GB restore to a separate host/volume, record elapsed time and application checks, retain the report. Until then RTO remains a hypothesis.

## 6. Monitoring

- Backup unit: `OnFailure=app-backup-failure.service` (+ optional Healthchecks URL).
- Weekly: `app-backup-check.timer` → `restic check --read-data-subset=10%`.
- RPO: `app-backup-rpo.timer` prints **last snapshot update time** and fails if age > `restic_rpo_hours`.

## 7. Operational evidence still required

- Successful backup/timer logs.
- Offsite copy + Object Lock / append-only evidence.
- Sample DR output with elapsed seconds.
- Quarterly full-restore timing report.
- Measured RPO/RTO, not estimates presented as achieved.
