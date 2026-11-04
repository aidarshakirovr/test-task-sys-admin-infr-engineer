# Object Lock / IAM verification checklist (UNVERIFIED)

Status: **UNVERIFIED** until run against a real bucket. This repository does not configure AWS.

Replace `BUCKET`, profiles, and prefixes before use.

## 1. App key cannot delete data objects

```bash
# Expect AccessDenied
AWS_PROFILE=app-backup aws s3api delete-object --bucket BUCKET --key data/some-pack-id
AWS_PROFILE=app-backup aws s3 rm s3://BUCKET/snapshots/dummy --dryrun
```

## 2. App key CAN delete under locks/ (restic unlock)

```bash
# Expect success (or object-not-found), not AccessDenied on locks/
AWS_PROFILE=app-backup aws s3api delete-object --bucket BUCKET --key locks/dummy-lock
```

## 3. App backup/copy works without blanket --no-lock

```bash
# On app host with app IAM (locks/ delete allowed)
sudo -u restic-backup restic backup /srv/app/data
# Prefer restic_no_lock=false unless single-writer is documented
```

## 4. Admin prune works (Governance or unlocked)

```bash
AWS_PROFILE=backup-admin ansible-playbook -i ansible/inventories/production/hosts.ini \
  ansible/playbooks/backup-retention.yml --ask-vault-pass --check --diff
# Live prune only after --check looks correct
```

## 5. Compliance mode note

If Object Lock **Compliance** is on, prune of locked objects will fail until retention expires — that is expected. Document chosen mode in the change ticket.

Operator: ________  Date: ________  Result: PASS / FAIL
