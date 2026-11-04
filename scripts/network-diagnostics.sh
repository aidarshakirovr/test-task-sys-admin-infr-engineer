#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== 1. Прослушиваемые сокеты (ss -tulpn) ==="
ss -tulpn | grep -E '8080|docker|LISTEN' || echo "Порт 8080 не прослушивается"

echo -e "\n=== 2. IP Forwarding ядра ==="
sysctl net.ipv4.ip_forward

echo -e "\n=== 3. Трансляция адресов Docker NAT (iptables) ==="
sudo iptables -t nat -L DOCKER -n -v 2>/dev/null || echo "Цепочка DOCKER отсутствует"

echo -e "\n=== 4. Анализ коллизий подсетей (Docker Subnets vs Host Routes) ==="
HOST_ROUTES=$(ip route | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' || true)
echo "Маршруты хоста:"
echo "${HOST_ROUTES}"

if command -v docker &>/dev/null; then
    echo -e "\nПодсети Docker:"
    docker network ls -q | while read -r net_id; do
        SUBNET=$(docker network inspect "$net_id" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
        NAME=$(docker network inspect "$net_id" --format '{{.Name}}' 2>/dev/null || true)
        if [[ -n "$SUBNET" ]]; then
            echo "- Сеть '${NAME}': ${SUBNET}"
            if echo "${HOST_ROUTES}" | grep -qw "${SUBNET}"; then
                echo "  [WARN] Обнаружен прямой конфликт подсети Docker с таблицей маршрутов хоста!"
            fi
        fi
    done
fi
echo -e "\nДиагностика сети завершена."
