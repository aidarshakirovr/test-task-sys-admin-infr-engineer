# Инженерное решение: Systems Administrator / Infrastructure Engineer

## 1. Резервное копирование и Disaster Recovery
- Standalone-реализация:
  - Restic с локальным хранилищем /var/backups/restic-repo.
  - Пользователь restic-backup (nologin), пароль /etc/restic/backup.pass (права 0640).
  - Исходные права данных сохраняются, доступ сервису выдан через наследуемые POSIX ACL (rX).
  - Идемпотентная инициализация репозитория (restic init выполняется только при отсутствии config).
  - Оркестрация: systemd.timer app-backup.timer (каждые 4 часа), Retention: 24h / 14d / 4w / 6m.
- Production: S3/Ceph в режиме WORM (Object Lock), Vault AppRole, метрики RPO <= 4 ч, RTO <= 30 мин.
- DR-тестирование: scripts/dr-restore-test.sh (restic check, восстановление в /tmp, побайтовая сверка SHA-256).

## 2. Docker Networking и диагностика
- Инцидент: биндинг на 127.0.0.1:8080. Исправление: 0.0.0.0:8080:80 и healthcheck в docker/compose.yaml.
- Диагностика: scripts/network-diagnostics.sh (ss, ip_forward, iptables NAT, расчет коллизий подсетей через Python ipaddress).
- Регламент сети: безопасное применение через sudo netplan try --timeout 120.

## 3. Развертывание
1. Установка коллекции:
ansible-galaxy collection install ansible.posix

2. Безопасный запуск через Vault:
ansible-playbook -i ansible/inventory.ini ansible/site.yml --ask-vault-pass
