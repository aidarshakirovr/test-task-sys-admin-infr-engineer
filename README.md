# Инженерное решение: Systems Administrator / Infrastructure Engineer

## 1. Резервное копирование и Disaster Recovery
- Текущая реализация (Standalone):
  - Restic с локальным хранилищем /var/backups/restic-repo.
  - Безопасность: сервисный пользователь restic-backup (shell: nologin), доступ к данным через POSIX ACL (rX) с наследованием default ACL.
  - Пароль хранится в /etc/restic/backup.pass с правами 0640 (группа restic-backup). В репозитории открытый пароль отсутствует.
  - Идемпотентная инициализация репозитория через Ansible (restic init выполняется только при отсутствии config).
  - Оркестрация: systemd.timer (app-backup.timer), запуск каждые 4 часа (*-*-* 00/4:00:00).
  - Retention Policy: 24 часовых, 14 ежедневных, 4 еженедельных, 6 ежемесячных снимков.
- Целевая Production-архитектура:
  - Хранилище S3/Ceph с режимом WORM (S3 Object Lock Compliance).
  - Изоляция: append-only доступ (PutObject) для хоста, удаление и ротация вынесены в изолированный Management-контур.
  - Управление секретами через HashiCorp Vault (AppRole).
- Метрики: RPO <= 4 ч, RTO <= 30 мин.
- DR-тестирование: scripts/dr-restore-test.sh (restic check, тестовое восстановление в /tmp и побайтовая сверка SHA-256 с исходным файлом).

## 2. Docker Networking и сетевая диагностика
- Root Cause: сокет слушал 127.0.0.1:8080 вместо 0.0.0.0:8080.
- Исправления: маппинг 0.0.0.0:8080:80 и healthcheck в docker/compose.yaml.
- Диагностика: scripts/network-diagnostics.sh (проверка сокетов, ip_forward, правил iptables NAT, автоматический поиск коллизий подсетей Docker и таблицы маршрутов ip route).
- Регламент сети: безопасное применение настроек через sudo netplan try --timeout 120.

## 3. Развертывание
Пароль передается через Ansible Vault или аргумент команды:
ansible-playbook -i ansible/inventory.ini ansible/site.yml -e "restic_password=YourProductionPassword2026!"
