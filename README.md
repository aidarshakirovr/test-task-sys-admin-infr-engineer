# Инженерное решение: Systems Administrator / Infrastructure Engineer

## 1. Резервное копирование и Disaster Recovery
- Текущая реализация (Standalone):
  - Restic, хранилище /var/backups/restic-repo.
  - Безопасность: системный пользователь restic-backup без shell, права на данные через наследуемые POSIX ACL (rX).
  - Пароль /etc/restic/backup.pass (права 0640), автоматический restic init при первом запуске через Ansible.
  - Оркестрация: systemd.timer (app-backup.timer) с ротацией снапшотов (forget --prune).
- Целевая Production-архитектура:
  - Хранилище S3 / Ceph в режиме WORM (Object Lock Compliance).
  - Изоляция: append-only права для агента бэкапа, удаление/ротация вынесены в Management-контур.
  - Управление секретами через HashiCorp Vault (AppRole).
- Расчетные метрики: RPO <= 4 ч, RTO <= 30 мин.
- DR-тестирование: скрипт scripts/dr-restore-test.sh (restic check, восстановление и сверка SHA-256).

## 2. Docker Networking и сетевая диагностика
- Root Cause: привязка порта к 127.0.0.1:8080 вместо 0.0.0.0:8080.
- Исправления: публикация 0.0.0.0:8080:80 и healthcheck в docker/compose.yaml.
- Скрипт диагностики: scripts/network-diagnostics.sh (проверка ss, ip_forward, iptables NAT, коллизии подсетей).
- Регламент сети: безопасное применение сетевых настроек через netplan try --timeout 120.

## 3. Структура проекта
- ansible/ — плейбук site.yml, роль backup_restic (пользователь, ACL, restic init)
- docker/ — исправленный compose.yaml
- scripts/ — backup-app.sh (обработчик trap), dr-restore-test.sh (SHA-256), network-diagnostics.sh (коллизии)
