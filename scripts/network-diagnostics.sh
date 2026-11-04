#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== 1. Прослушиваемые сокеты (L4) и IP Forwarding ==="
ss -tulpn | grep -E '8080|docker|LISTEN' || true
sysctl net.ipv4.ip_forward

echo -e "\n=== 2. Firewall и Netfilter (UFW / iptables) ==="
command -v ufw &>/dev/null && sudo ufw status || true
sudo iptables -S DOCKER-USER 2>/dev/null || true
sudo iptables -L FORWARD -n -v --line-numbers 2>/dev/null | head -n 10 || true
sudo iptables -t nat -L DOCKER -n -v 2>/dev/null || true

echo -e "\n=== 3. DNS-диагностика ==="
getent hosts localhost google.com >/dev/null && echo "[OK] DNS резолвинг работает корректно" || echo "[WARN] Сбой DNS"

echo -e "\n=== 4. Анализ коллизий подсетей (Python ipaddress) ==="
HOST_ROUTES=$(ip route | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' || true)
echo "Маршруты хоста: ${HOST_ROUTES}"

DOCKER_CMD="docker"
! docker ps &>/dev/null && command -v sudo &>/dev/null && DOCKER_CMD="sudo docker"

if command -v docker &>/dev/null; then
    echo "Подсети Docker:"
    $DOCKER_CMD network ls -q 2>/dev/null | while read -r net_id; do
        SUBNET=$($DOCKER_CMD network inspect "$net_id" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
        NAME=$($DOCKER_CMD network inspect "$net_id" --format '{{.Name}}' 2>/dev/null || true)
        if [[ -n "$SUBNET" ]]; then
            python3 -c "import ipaddress, sys; d=ipaddress.ip_network(sys.argv[1]); [print(f'  [WARN] Коллизия: {sys.argv[2]} ({d}) с {r}') for r in sys.argv[3].split() if d.overlaps(ipaddress.ip_network(r))]" "${SUBNET}" "${NAME}" "${HOST_ROUTES}"
        fi
    done
fi
echo -e "\n[SUCCESS] Сетевая диагностика завершена."
