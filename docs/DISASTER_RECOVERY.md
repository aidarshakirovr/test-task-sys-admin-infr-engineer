# Disaster Recovery Plan

## 1. Scope and recovery objectives

- Protected path: `/srv/app/data` (estimated 100 GB; measure actual used bytes).
- Backup interval: every 4 hours, **only if** the deployed systemd timer uses `restic_schedule`.
- Target RPO: at most 4 hours, subject to successful backup completion and alerting.
- Target RTO: **not yet demonstrated**. A 30-minute target must not be claimed until a full restore is timed on representative hardware and network/storage.

Restic performs block-level deduplication and encryption. It does not require users to create a separate tar/zip archive for space savings.

## 2. Storage and ransomware protection

A local repository on the application host is useful for fast recovery, but it is not an independent ransomware-protected copy. A root compromise of that host can delete it.

For production, keep an off-host copy and implement at least one independently administered immutability control:

- S3 Object Lock in Compliance mode, configured on a bucket that supports Object Lock, with a documented retention period; or
- a separately administered backup host running `rest-server` in append-only mode.

These controls are **not enabled by this repository's Ansible defaults alone**. Do not claim WORM/append-only protection until the remote service or bucket policy is configured and tested. Run `forget`/`prune` only from a separate administrative context with the required delete permissions. Do not apply `chattr +a` to a normal Restic repository: Restic needs to manage repository files and this can break maintenance.

## 3. Restore runbooks

### Restore selected files to a staging path

```bash
sudo install -d -m 0750 /var/tmp/recovery
sudo -u restic-backup restic \
  -r /var/backups/restic-repo \
  --password-file /etc/restic/backup.pass \
  restore latest --target /var/tmp/recovery \
  --include /srv/app/data/config.json
```

Review the restored file, ownership, permissions, and contents before copying it into production. Do not restore directly over a live directory without an approved change and rollback plan.

### Full host recovery

1. Provision a clean host and install the required OS packages.
2. Restore Ansible configuration and secrets from the approved secure source.
3. Install the Restic version used by the backup environment.
4. Mount or configure access to the off-host repository; verify credentials.
5. List snapshots and run `restic check`.
6. Restore to a staging mount or recovery volume with sufficient free space.
7. Verify checksums, ownership, permissions, application configuration, and service health.
8. Switch traffic only after application-level validation.

A command such as `restore --target /` should only be used in a controlled bare-metal recovery procedure with a verified target filesystem. It is not the default runbook command.

## 4. DR verification

`scripts/dr-restore-test.sh` performs a sample restore of existing files into an isolated temporary directory, checks the repository, and compares SHA-256 hashes. It does not initialize repositories, create probe files in production data, or generate placeholder passwords.

Run it as an identity that can read the repository, password file, and source data:

```bash
sudo -u restic-backup \
  RESTIC_REPOSITORY=/var/backups/restic-repo \
  RESTIC_PASSWORD_FILE=/etc/restic/backup.pass \
  BACKUP_SOURCE_DIR=/srv/app/data \
  bash scripts/dr-restore-test.sh
```

This is a sample verification, not proof of a complete 100 GB recovery. Schedule a full restore to a separate staging host/volume at least quarterly, record elapsed time and application checks, and retain the report.

## 5. Network change safety

1. Capture current state: `ip addr`, `ip route`, `ip rule`, `iptables-save` (or nftables ruleset), and relevant Docker configuration.
2. Test changes in staging and review them through version control.
3. Keep console/out-of-band access and a tested rollback command.
4. For Netplan, use `netplan try` with a timeout where supported.
5. Verify from a second machine: `curl`, `nc`, and `tcpdump`; also inspect `ss -tlnp`, `ip route get CLIENT_IP`, UFW/nftables, `DOCKER-USER`, NAT, and Docker port mappings.
6. Do not delete firewall rules blindly. Identify the rule, capture counters, make one scoped change, and verify rollback.

## 6. Operational evidence still required

- Successful backup and timer logs.
- Off-host copy and immutability configuration evidence.
- Sample DR test output.
- Quarterly full-restore timing and application smoke-test report.
- Measured RPO/RTO, not estimates presented as achieved results.
