#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== 1. Прослушиваемые сокеты (ss -tulpn) ==="
ss -tulpn | grep -E '8080|docker|LISTEN' || echo "Порт 8080 не прослушивается"

echo -e "\n=== 2. IP Forwarding ядра ==="
sysctl net.ipv4.ip_forward

echo -e "\n=== 3. Трансляция адресов Docker NAT (iptables) ==="
sudo iptables -t nat -L DOCKER -n -v 2>/dev/null || echo "Цепочка DOCKER отсутствует"

echo -e "\n=== 4. Анализ коллизий подсетей (Python ipaddress overlaps) ==="
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
            python3 -c "
import ipaddress, sys
docker_sub = sys.argv[1]
net_name = sys.argv[2]
routes = sys.argv[3].split()
try:
    d_net = ipaddress.ip_network(docker_sub, strict=False)
    for r in routes:
        try:
            h_net = ipaddress.ip_network(r, strict=False)
            if d_net.overlaps(h_net):
                print(f'  [WARN] Обнаружена коллизия: сеть Docker {net_name} ({d_net}) пересекается с маршрутом хоста ({h_net})')
        except ValueError:
            pass
except ValueError:
    pass
" "${SUBNET}" "${NAME}" "${HOST_ROUTES}"
        fi
    done
fi
echo -e "\nДиагностика сети завершена."
