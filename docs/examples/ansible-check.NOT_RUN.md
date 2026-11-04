# ansible-playbook --check — NOT RUN

**Date:** 2026-11-04 (lab workstation)

**Blocked:** no disposable staging VM / SSH target is available in this Windows workspace.

What was run instead:

- `bash scripts/ci-local.sh` (syntax-check / lint / shellcheck where installed)
- No live `--check --diff` against inventory hosts

To complete evidence on a real lab VM:

```bash
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/site.yml \
  --ask-vault-pass --check --diff
ansible-playbook -i ansible/inventories/staging/hosts.ini \
  ansible/playbooks/backup-retention.yml --ask-vault-pass --check --diff
```

Do not treat this file as a successful apply.
