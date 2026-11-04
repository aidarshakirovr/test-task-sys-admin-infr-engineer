# Disaster Recovery Plan & Threat Model

## 1. RPO / RTO Metrics (100 GB Data)
- **RPO:** <= 4 hours (systemd.timer every 4h, block deduplication).
- **RTO:** <= 30 mins (Ansible deploy ~5m, 100GB network restore ~15m, smoke test ~5m).
- **3-2-1 Rule:** Local repo (/var/backups/restic-repo) + Offsite S3/MinIO (AES-256).

## 2. Threat Model & Ransomware Protection
- **Accidental deletion:** dedicated restic-backup user (nologin) with read-only POSIX ACL (r-x) on /srv/app/data.
- **Host root compromise & Ransomware:** S3 Object Lock in Compliance mode (WORM) + rest-server --append-only prevents backup deletion/encryption even from root. Systemd unit hardened with ProtectSystem=strict.

## 3. Recovery Runbooks
- **Single file:** sudo -u restic-backup restic -r /var/backups/restic-repo --password-file /etc/restic/backup.pass restore latest --target /tmp/rec --include /srv/app/data/file
- **Full Bare-Metal:** ansible-playbook -i ansible/inventories/production/hosts.ini ansible/site.yml && sudo -u restic-backup restic -r /var/backups/restic-repo --password-file /etc/restic/backup.pass restore latest --target /

## 4. DR-Testing Plan & RACI
- **Automated Weekly:** scripts/dr-restore-test.sh runs restic check, restores to /tmp, and verifies SHA-256 hashes.
- **Quarterly GameDay:** Full bare-metal restore drill on staging.
- **RACI:** Responsible: Infra Engineer | Accountable: Team Lead | Consulted: SecOps | Informed: CTO.

## 5. Production Network Change Management
- All changes tested in staging via IaC (Ansible/Git).
- Pre-change backup: iptables-save > /root/iptables.bak.
- Safe apply with auto-rollback: sudo netplan try --timeout 120.
