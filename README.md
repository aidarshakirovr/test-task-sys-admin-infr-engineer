# Решение тестового задания: Systems Administrator / Infrastructure Engineer

## 1. Резервное копирование и Disaster Recovery
- **Текущая Standalone-реализация:**
  - Утилита: Restic (дедупликация CDC, шифрование).
  - Хранилище: локальная директория `/var/backups/restic-repo`.
  - Доставка пароля и инициализация: через Ansible (`/etc/restic/backup.pass`, права `0600`, автоматический `restic init` при первом запуске).
  - Оркестрация: `systemd.timer` (`app-backup.timer`) с ротацией снапшотов (`forget --prune`).
- **Целевая Production-архитектура:**
  - Хранилище: S3 / Ceph с включенным режимом WORM (S3 Object Lock Compliance).
  - Безопасность: хост с правами append-only (`PutObject`), ротация вынесена в изолированный Management-контур.
  - Управление секретами: интеграция с HashiCorp Vault (AppRole).
- **Расчетные метрики:** RPO <= 4 ч (инкремент 1–3 мин), RTO <= 30 мин (восстановление 100 ГБ по 1 Gbps).
- **DR-тестирование:** скрипт `scripts/dr-restore-test.sh` проверяет репозиторий (`restic check`), восстанавливает снапшот и сверяет SHA-256 контрольные суммы.

## 2. Docker Networking и сетевая диагностика
- **Root Cause:** сокет сервиса слушал loopback (`127.0.0.1:8080`) вместо `0.0.0.0:8080`, внешний трафик сбрасывался хостом.
- **Исправления:** маппинг `0.0.0.0:8080:80` в `docker/compose.yaml`, добавлен `healthcheck`.
- **Скрипт диагностики:** `scripts/network-diagnostics.sh` (проверка сокетов `ss`, форвардинга `ip_forward`, iptables NAT, коллизий подсетей).
- **Регламент сети:** безопасное применение настроек через `sudo netplan try --timeout 120`.

## 3. Структура проекта
- `ansible/` — плейбук `site.yml` и идемпотентная роль `backup_restic`
- `docker/` — исправленный манифест `compose.yaml`
- `scripts/` — скрипты `backup-app.sh`, `dr-restore-test.sh`, `network-diagnostics.sh`
