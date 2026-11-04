# Infrastructure & SysAdmin Engineering Solution

## 1. Backup & Disaster Recovery (Task 1)
- **3-2-1 Architecture:** Restic (AES-256) with local repo (/var/backups/restic-repo) and S3/MinIO support in Ansible.
- **Security & Ransomware Protection:** restic-backup user (nologin), POSIX ACL (rX), systemd sandbox (ProtectSystem=strict), S3 Object Lock (WORM) & Append-Only mode.
- **Metrics (100 GB):** systemd.timer every 4h (RPO <= 4h, RTO <= 30m), GFS retention: 24h / 14d / 8w / 6m.
- **Runbooks & DR Tests:** Detailed in [docs/DISASTER_RECOVERY.md](docs/DISASTER_RECOVERY.md) and verified via scripts/dr-restore-test.sh (SHA-256 check).

## 2. Production Network Incident & Diagnostics (Task 2)
- **Root Cause & Fix:** Container bound to 127.0.0.1:8080 instead of 0.0.0.0:8080:80; verified via compose healthcheck.
- **Automated Audit:** scripts/network-diagnostics.sh checks sockets (ss), routing (ip route/rule), ip_forward, UFW, DOCKER-USER / FORWARD / NAT chains, DNS, and Docker subnet overlaps via Python ipaddress.
- **Safe Change Management:** Staging verification, IaC, iptables-save backup, and sudo netplan try --timeout 120.

## 3. Verification
- bash scripts/network-diagnostics.sh
- sudo bash scripts/dr-restore-test.sh
