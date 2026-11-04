# Инженерное решение: Systems Administrator / Infrastructure Engineer

## 1. Резервное копирование и Disaster Recovery
- Standalone-реализация:
  - Restic с локальным хранилищем /var/backups/restic-repo и поддержкой S3 в коде Ansible.
  - Сервисный пользователь restic-backup (nologin), пароль /etc/restic/backup.pass (0640).
  - Данные защищены через POSIX ACL (rX) без изменения прав рабочего каталога приложения.
  - Изоляция systemd: ProtectSystem=strict, выделен кэш /var/cache/restic-backup.
  - Расписание: systemd.timer каждые 4 часа, Retention: 24h / 14d / 4w / 6m.
- Регламент DR и Runbooks вынесены в docs/DISASTER_RECOVERY.md (RPO <= 4 ч, RTO <= 30 мин, матрица RACI).
- DR-тестирование: scripts/dr-restore-test.sh (restic check, распаковка, сверка хэшей SHA-256).

## 2. Сети и диагностика
- Инцидент: биндинг на 127.0.0.1:8080. Исправление: 0.0.0.0:8080:80 и healthcheck в docker/compose.yaml.
- Скрипт scripts/network-diagnostics.sh: аудит ss, net.ipv4.ip_forward, UFW, цепочек DOCKER-USER/FORWARD, DNS и вычисление коллизий через Python ipaddress.
- Регламент сети: безопасное применение настроек через sudo netplan try --timeout 120.

## 3. Развертывание
1. Установка коллекции:
ansible-galaxy collection install ansible.posix

2. Развертывание (staging / production):
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/site.yml --ask-vault-pass
