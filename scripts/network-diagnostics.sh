#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== 1. Прослушиваемые сокеты (L4) и IP Forwarding ==="
ss -tulpn | grep -E '8080|docker|LISTEN' || true
sysctl net.ipv4.ip_forward || true

echo -e "\n=== 2. Таблица маршрутизации и Policy Routing (L3) ==="
ip -br addr show
ip route show
ip rule show

echo -e "\n=== 3. Firewall и Netfilter (UFW / iptables / NAT) ==="
if command -v ufw &>/dev/null; then
    sudo ufw status verbose || true
fi
sudo iptables -S DOCKER-USER 2>/dev/null || true
sudo iptables -L FORWARD -n -v --line-numbers 2>/dev/null | sed -n '1,15p' || true
sudo iptables -t nat -L DOCKER -n -v --line-numbers 2>/dev/null || true

echo -e "\n=== 4. DNS-диагностика ==="
if getent hosts localhost >/dev/null; then
    echo "[OK] Локальный резолвинг (NSS/hosts) работает корректно"
else
    echo "[WARN] Сбой локального резолвинга"
fi
resolvectl status 2>/dev/null | sed -n '1,12p' || cat /etc/resolv.conf || true

echo -e "\n=== 5. Анализ коллизий подсетей (Python ipaddress) ==="
HOST_ROUTES=$(ip route | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+/ {print $1}' | tr '\n' ' ')
echo "Маршруты хоста: ${HOST_ROUTES:-не обнаружены}"

DOCKER_CMD="docker"
if ! docker ps &>/dev/null && command -v sudo &>/dev/null; then
    DOCKER_CMD="sudo docker"
fi

if command -v docker &>/dev/null && $DOCKER_CMD ps &>/dev/null; then
    echo "Проверка подсетей Docker:"
    for net_id in $($DOCKER_CMD network ls -q 2>/dev/null); do
        SUBNET=$($DOCKER_CMD network inspect "$net_id" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
        NAME=$($DOCKER_CMD network inspect "$net_id" --format '{{.Name}}' 2>/dev/null || true)
        if [[ -n "$SUBNET" ]]; then
            echo "  - Сеть Docker: ${NAME} (${SUBNET})"
            python3 -c "
import ipaddress, sys
d = ipaddress.ip_network(sys.argv[1], strict=False)
name = sys.argv[2]
for r in sys.argv[3].split():
    hr = ipaddress.ip_network(r, strict=False)
    if d.overlaps(hr) and d != hr:
        print(f'  [WARN] Обнаружена коллизия подсетей: Docker {name} ({d}) пересекается с маршрутом хоста {hr}')
" "${SUBNET}" "${NAME}" "${HOST_ROUTES}"
        fi
    done
else
    echo "[INFO] демон Docker недоступен или не установлен, пропуск проверки Docker-сетей."
fi

echo -e "\n[SUCCESS] Сетевая диагностика успешно завершена."
