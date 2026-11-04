# S3 Object Lock, locks/, and IAM for offsite backups

This Ansible role does **not** enable Object Lock or attach IAM policies. Configure and verify them manually before claiming ransomware resistance.

## Recommended app-host IAM (restic needs lock release)

Restic creates/releases lock objects under `locks/`. A blanket Deny on all `DeleteObject` breaks backups.

Allow DeleteObject **only** under the locks prefix; deny delete on data/index/snapshots:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::BUCKET"
    },
    {
      "Sid": "ReadWriteObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::BUCKET/*"
    },
    {
      "Sid": "UnlockOnlyLocksPrefix",
      "Effect": "Allow",
      "Action": ["s3:DeleteObject", "s3:DeleteObjectVersion"],
      "Resource": "arn:aws:s3:::BUCKET/locks/*"
    },
    {
      "Sid": "DenyDeleteData",
      "Effect": "Deny",
      "Action": ["s3:DeleteObject", "s3:DeleteObjectVersion"],
      "NotResource": "arn:aws:s3:::BUCKET/locks/*"
    }
  ]
}
```

Alternative (riskier): set `restic_no_lock: true` so backup/copy use `--no-lock`. Only with a documented single-writer guarantee. Default is `false`.

Admin/`backup_admin` credentials keep DeleteObject on data keys for `forget --prune`.

## Object Lock vs prune (contradiction)

| Mode | Effect on prune |
|------|-----------------|
| **Compliance** | Locked objects cannot be deleted by anyone until retention expires. `forget --prune` will fail or leave locked packs. |
| **Governance** | Privileged admin can override retention and prune (still protect from app-host keys). |
| **Lifecycle expire** | Let Object Lock/lifecycle age out objects instead of restic prune. |

**Checklist (manual — not done by this role):**

1. Bucket created with Object Lock + versioning.
2. Mode chosen (Governance recommended if you need prune; Compliance if legal hold).
3. App IAM as above (locks/ delete only).
4. Admin IAM used only from `backup_admin` for retention.
5. Verified with a test `forget --prune` and a denied delete from app keys.

Do **not** claim Object Lock is configured solely because docs mention it.
