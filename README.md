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
(client `curl`/`nc` → `ss` → `docker port` → UFW/`DOCKER-USER`/FORWARD/NAT with counters → `ip route get` / Docker overlap → `tcpdump` → DNS). Do not delete firewall rules blindly.

## What was verified vs not

| Item | Status |
|------|--------|
| Role templates / scripts syntax intent | Present in repo; run `bash -n` / `ansible-playbook --syntax-check` locally |
| Ansible `--check` on disposable staging VM | **Not claimed** until you run it |
| Live S3 Object Lock / append-only rest-server | **Must be configured and tested outside defaults** |
| Full 100 GB restore timing (RTO) | **Not measured** — hypothesis only |
| Sample DR script against real data | **Not claimed** until executed on a host with a real repo |

## Validation

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/site.yml --syntax-check
bash -n scripts/network-diagnostics.sh scripts/dr-restore-test.sh
```

Run Ansible `--check --diff` against a disposable staging VM before production. Do not run the DR test until the repository and password file already exist.
