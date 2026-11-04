# Systems Administrator / Infrastructure Engineer — Test Task

## What lives where

| Path | Purpose |
|------|---------|
| `ansible/roles/backup_restic/` | Restic backup user, repo init, systemd timer/service, check & RPO timers |
| `ansible/roles/host_hardening/` | SSH hardening, UFW (allow then enable), Docker `daemon.json` pools |
| `ansible/playbooks/backup-retention.yml` | `forget --prune` from a **separate** admin host only |
| `ansible/site.yml` | Hardening + backup roles |
| `ansible/inventories/` | staging / production inventories |
| `scripts/dr-restore-test.sh` | Sample DR restore (random files, timing, optional smoke) |
| `scripts/network-diagnostics.sh` | Read-only network / Docker / firewall snapshot |
| `docs/DISASTER_RECOVERY.md` | Restore + DR plan, consistency, RTO hypothesis |
| `docs/NETWORK_INCIDENT_RUNBOOK.md` | Ordered production network incident checks |
| `docs/NETWORK_INCIDENT_CASE.md` | Task 2 root cause: Docker subnet vs LAN |
| `docs/examples/dr-restore-test.sample.log` | SAMPLE DR test fixture (not production) |
| `.github/workflows/validate.yml` | CI: galaxy, syntax-check, ansible-lint, shellcheck |
| `docker/compose.yaml` | Example published web service |

## Backup and recovery

- **Tool:** Restic (encrypted, deduplicated). Scheduling via **systemd timer** (`restic_schedule`, every 4 hours).
- **Prune:** not on the backup host. Retention runs from `ansible/playbooks/backup-retention.yml`; give the app host an S3 key **without** delete.
- **Offsite:** set `restic_copy_enabled: true` and `restic_secondary_repo_path` so each run executes `restic copy`.
- **Access to data:** `AmbientCapabilities=CAP_DAC_READ_SEARCH` (no recursive ACL on 100 GB).
- **Secrets:** Ansible Vault. Tasks that handle passwords/keys use `no_log: true`.

### Create and encrypt Vault

```bash
cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
# edit vault_restic_password / vault_s3_* then:
ansible-vault encrypt ansible/group_vars/all/vault.yml
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/site.yml \
  --ask-vault-pass --check --diff
```

Target RPO ≤ 4 hours (timer + RPO age check). RTO is a **hypothesis** until a full restore is timed — see `docs/DISASTER_RECOVERY.md`.

## Network diagnostics and incident response

```bash
bash scripts/network-diagnostics.sh
```

Ordered incident runbook: `docs/NETWORK_INCIDENT_RUNBOOK.md`  
Case write-up (Docker subnet overlap): `docs/NETWORK_INCIDENT_CASE.md`  
(client `curl`/`nc` → `ss` → `docker port` → UFW/`DOCKER-USER`/FORWARD/NAT with counters → `ip route get` / Docker overlap → `tcpdump` → DNS). Do not delete firewall rules blindly.

Docker `daemon.json` changes restart the daemon (containers stop — maintenance window). `default-address-pools` apply only to **new** networks; recreate overlapping ones manually.

## What was verified vs not

| Item | Status |
|------|--------|
| CI workflow file | `.github/workflows/validate.yml` + `scripts/ci-local.sh` in repo; enable Actions after push |
| Local `bash scripts/ci-local.sh` | Preferred local gate |
| Ansible `--check` on disposable staging VM | **Not run here** — no staging VM in this workspace; run before prod |
| Live S3 Object Lock / IAM | **Manual** — see `docs/S3_OBJECT_LOCK_AND_IAM.md` (not auto-configured) |
| Full 100 GB restore timing (RTO) | **Hypothesis** — fill `docs/examples/full-restore-timing.template.md` |
| Sample DR log | EXAMPLE fixture only |

## Validation

```bash
bash scripts/ci-local.sh
```

Run Ansible `--check --diff` against a disposable staging VM before production (not available in this workspace). Do not run the DR test until the repository and password file already exist.
