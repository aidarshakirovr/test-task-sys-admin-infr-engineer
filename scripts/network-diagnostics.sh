#!/usr/bin/env bash
set -Eeuo pipefail

echo "=================================================="
echo "    ДИАГНОСТИКА СЕТЕВОГО СТЕКА И DOCKER"
echo "=================================================="

echo -e "\n1. Прослушиваемые сокеты (ss -tulpn):"
ss -tulpn | grep -E '8080|docker|LISTEN' || echo "Сокет 8080 не обнаружен"

echo -e "\n2. Параметры ядра (IP Forwarding):"
sysctl net.ipv4.ip_forward

echo -e "\n3. Цепочки трансляции адресов Docker NAT (iptables):"
sudo iptables -t nat -L DOCKER -n -v || echo "Цепочка DOCKER в iptables отсутствует"

echo -e "\n4. Проверка коллизий подсетей (Docker Subnets vs Host Routes):"
echo "--- Маршруты хоста (ip route) ---"
ip route

echo -e "\n--- Подсети Docker-сетей ---"
if command -v docker &> /dev/null; then
    docker network ls -q | while read -r net_id; do
        SUBNET=$(docker network inspect "$net_id" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
        NAME=$(docker network inspect "$net_id" --format '{{.Name}}' 2>/dev/null || true)
        if [[ -n "$SUBNET" ]]; then
            echo "Сеть: ${NAME} -> Подсеть: ${SUBNET}"
        fi
    done
else
    echo "Docker демон не установлен или недоступен"
fi

echo -e "\n=================================================="
echo "Диагностика завершена."
