# Disaster Recovery Plan, Threat Model & Runbooks

## 1. Метрики RPO и RTO
- RPO (Recovery Point Objective): <= 4 часа (запуск бэкапа по таймеру каждые 4 ч).
- RTO (Recovery Time Objective): <= 30 минут (Ansible ~5 мин, распаковка снапшота ~10 мин, тесты ~10 мин).

## 2. Модель угроз (Threat Modeling)
- Компрометация хоста приложения: пользователь restic-backup изолирован (nologin), пароль защищен правами 0640.
- Ransomware / эскалация прав: песочница systemd (ProtectSystem=strict, ProtectHome=read-only). Целевая архитектура: S3 с WORM Object Lock (Compliance).
- Человеческий фактор: каталог /srv/app/data защищен POSIX ACL без модификации системных прав.

## 3. Сценарии восстановления (Runbooks)
Сценарий А: Восстановление файла (до 5 мин):
sudo -u restic-backup restic -r /var/backups/restic-repo --password-file /etc/restic/backup.pass restore latest --target /tmp/recovery --include /srv/app/data/config.json
sudo cp /tmp/recovery/srv/app/data/config.json /srv/app/data/config.json
sudo rm -rf /tmp/recovery

Сценарий Б: Полный отказ хоста (Bare-Metal Restore):
1. Развертывание окружения:
ansible-galaxy collection install ansible.posix
ansible-playbook -i ansible/inventories/staging/hosts.ini ansible/site.yml --ask-vault-pass
2. Восстановление данных:
sudo -u restic-backup restic -r /var/backups/restic-repo --password-file /etc/restic/backup.pass restore latest --target /
3. Запуск и проверка:
docker compose -f docker/compose.yaml up -d
curl -f http://localhost:8080/health

## 4. План регулярного DR-тестирования
- Периодичность: Ежеквартально (GameDay) и еженедельный автопрогон scripts/dr-restore-test.sh.
- Матрица RACI: Responsible - Инженер инфраструктуры; Accountable - Team Lead; Consulted - Security; Informed - CTO.
- Критерии успеха: код restic check = 0; 100% совпадение хэшей SHA-256; ответ HTTP 200 OK.
