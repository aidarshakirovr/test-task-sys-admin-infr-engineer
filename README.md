# Инженерное решение: Systems Administrator / Infrastructure Engineer

## 1. Резервное копирование и Disaster Recovery
- Текущая реализация (Standalone):
  - Restic с локальным хранилищем /var/backups/restic-repo.
  - Безопасность: системный пользователь restic-backup (без shell), права на данные через раздельные POSIX ACL (rX) с наследованием default ACL.
  - Пароль хранится в /etc/restic/backup.pass (права 0640, группа restic-backup).
  - Идемпотентная инициализация репозитория через Ansible (restic init выполняется только при отсутствии config).
  - Оркестрация: systemd.timer (app-backup.timer), запуск каждые 4 часа.
  - Политика Retention: 24 часовых, 14 ежедневных, 4 еженедельных, 6 ежемесячных снимков.
- Целевая Production-архитектура:
  - Хранилище S3/Ceph в режиме WORM (Object Lock Compliance).
  - Изоляция: append-only доступ для хоста, удаление/ротация вынесены в Management-контур.
  - Управление секретами через HashiCorp Vault (AppRole).
- Метрики: RPO <= 4 ч, RTO <= 30 мин.
- DR-тестирование: scripts/dr-restore-test.sh (restic check, тестовое восстановление и сверка SHA-256).

## 2. Docker Networking и сетевая диагностика
- Root Cause: сокет слушал 127.0.0.1:8080 вместо 0.0.0.0:8080.
- Исправления: маппинг 0.0.0.0:8080:80, healthcheck в docker/compose.yaml.
- Диагностика: scripts/network-diagnostics.sh (проверка сокетов, ip_forward, iptables NAT, проверка коллизий подсетей Docker и маршрутов хоста).
- Регламент сети: безопасное применение через sudo netplan try --timeout 120.

## 3. Развертывание
Пароль передается через Ansible Vault или аргумент:
ansible-playbook -i ansible/inventory.ini ansible/site.yml -e "restic_password=SuperSecretPassword2026!"
