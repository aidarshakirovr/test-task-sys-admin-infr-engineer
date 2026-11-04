# Инженерное решение: Systems Administrator / Infrastructure Engineer

## 1. Резервное копирование и Disaster Recovery
- Текущая реализация (Standalone PoC):
  - Restic с локальным репозиторием /var/backups/restic-repo.
  - Безопасность: сервисный пользователь restic-backup (shell: nologin), права на данные через POSIX ACL (rX) с наследованием default ACL. Исходные права /srv/app/data не перезаписываются.
  - Пароль хранится в /etc/restic/backup.pass с правами 0640 (группа restic-backup). Открытый пароль исключён из репозитория.
  - Кэш Restic вынесен в изолированный каталог /var/cache/restic-backup (права 0750) под управлением ProtectSystem=strict.
  - Идемпотентная инициализация репозитория через Ansible (restic init выполняется только при отсутствии config).
  - Оркестрация: systemd.timer app-backup.timer (каждые 4 часа, без зависимости Requires на сервис).
  - Retention Policy: 24 часовых, 14 ежедневных, 4 еженедельных, 6 ежемесячных снимков.
- Целевая Production-архитектура (Roadmap):
  - Миграция хранилища на S3/Ceph с включенным режимом WORM (S3 Object Lock Compliance).
  - Изоляция контуров: append-only доступ (PutObject) для хоста, удаление и ротация вынесены в Management-контур.
  - Управление секретами через HashiCorp Vault (AppRole).
- Метрики: RPO <= 4 ч, RTO <= 30 мин.
- DR-тестирование: scripts/dr-restore-test.sh выполняет restic check, распаковку последнего снапшота в /tmp/dr-restore-test и побайтовое сравнение контрольных сумм по SHA-256.

## 2. Docker Networking и сетевая диагностика
- Инцидент: биндинг сокета на 127.0.0.1:8080 вместо 0.0.0.0:8080.
- Исправления: публикация 0.0.0.0:8080:80 и healthcheck в docker/compose.yaml.
- Диагностика: scripts/network-diagnostics.sh (ss, ip_forward, правила iptables NAT, расчет коллизий подсетей через модуль Python ipaddress).
- Регламент сети: безопасное применение сетевых правок через sudo netplan try --timeout 120.

## 3. Развертывание
1. Установка коллекции Ansible:
ansible-galaxy collection install ansible.posix

2. Развертывание через Ansible Vault:
ansible-playbook -i ansible/inventory.ini ansible/site.yml --ask-vault-pass
