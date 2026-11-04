# S3 Object Lock and IAM for offsite backups

App-host credentials must be **unable to delete** backup objects. Retention (`forget --prune`) runs only from `backup_admin`.

## Bucket

1. Create the offsite bucket with **Object Lock enabled** at creation time (cannot be added later on many providers).
2. Prefer **Compliance** mode with a retention period covering ransomware recovery (e.g. 30–90 days).
3. Enable versioning (required for Object Lock).

## IAM policy sketch (app host — write/list only)

Deny `s3:DeleteObject`, `s3:DeleteObjectVersion`, and `s3:PutLifecycleConfiguration` for the backup prefix. Allow `s3:PutObject`, `s3:GetObject`, `s3:ListBucket`.

Admin/break-glass role retains delete/prune permissions and is used only by `ansible/playbooks/backup-retention.yml`.

## Ansible

- `restic_copy_enabled: true` on production backup servers.
- Distinct `vault_restic_secondary_password` recommended.
- Documented in `docs/DISASTER_RECOVERY.md`.
