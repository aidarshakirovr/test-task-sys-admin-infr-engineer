# Systems Administrator / Infrastructure Engineer — Test Task

## Backup and recovery

The project uses Restic for encrypted, deduplicated backups. The role supports a local repository and an S3-compatible repository. Configure secrets with Ansible Vault; the defaults intentionally do not contain a usable password.

The intended backup interval is four hours (target RPO <= 4 hours), provided the deployed systemd timer consumes `restic_schedule` and successful runs are monitored. The RTO is not asserted as achieved until a full restore is timed.

A local repository on the source host is not ransomware-resistant. S3 Object Lock or an append-only backup server must be configured independently and verified before claiming immutable backup protection.

See `docs/DISASTER_RECOVERY.md` for restore procedures and DR verification.

## Network diagnostics

Run:

```bash
bash scripts/network-diagnostics.sh
```

The script reports listening sockets, routes, forwarding, firewall/NAT state, DNS, Docker published ports, and possible Docker subnet overlaps. It does not modify firewall or network configuration.

For an external reachability incident, also test from a second machine with `curl`/`nc` and capture packets with `tcpdump`.

## Validation

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/site.yml --syntax-check
bash -n scripts/network-diagnostics.sh scripts/dr-restore-test.sh
```

Run Ansible `--check` against a disposable staging VM before production. Do not run the DR test until the repository and password file already exist.
