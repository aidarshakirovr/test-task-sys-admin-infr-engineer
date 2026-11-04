#!/usr/bin/env bash
set -Eeuo pipefail

section() { printf '\n=== %s ===\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

APP_PORT="${APP_PORT:-${HARDENING_APP_PORT:-8080}}"

section "1. Listening sockets and forwarding"
if have ss; then
  ss -tulpn || true
else
  echo "[WARN] ss is not installed"
fi
if have sysctl; then
  sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding 2>/dev/null || true
  sysctl net.ipv4.conf.all.rp_filter net.ipv4.conf.default.rp_filter 2>/dev/null || true
fi

section "2. Addresses and routing"
ip -br addr show 2>/dev/null || true
ip -4 route show 2>/dev/null || true
ip -6 route show 2>/dev/null || true
ip rule show 2>/dev/null || true

section "3. Firewall and NAT"
if have ufw; then
  sudo ufw status verbose || true
  if [[ -f /etc/default/ufw ]]; then
    grep -E 'DEFAULT_FORWARD_POLICY|IPT_SYSCTL' /etc/default/ufw 2>/dev/null || true
  fi
  sudo ufw status | grep -i route || true
fi
if have iptables; then
  echo "[INFO] iptables backend: $(iptables -V 2>/dev/null || true)"
  sudo iptables -S DOCKER-USER 2>/dev/null || echo "[INFO] DOCKER-USER chain unavailable"
  # sed reads the full stream, avoiding the SIGPIPE that head can cause with pipefail.
  sudo iptables -L FORWARD -n -v --line-numbers 2>/dev/null | sed -n '1,15p' || true
  sudo iptables -t nat -L DOCKER -n -v --line-numbers 2>/dev/null || true
  sudo iptables -L -n -v 2>/dev/null | grep -i conntrack | sed -n '1,10p' || true
fi
if have nft; then
  sudo nft list ruleset 2>/dev/null | sed -n '1,160p' || true
fi

section "4. DNS"
if getent hosts localhost >/dev/null 2>&1; then
  echo "[OK] localhost name resolution works"
else
  echo "[WARN] localhost name resolution failed"
fi
if have resolvectl; then
  resolvectl status 2>/dev/null | sed -n '1,40p' || true
else
  cat /etc/resolv.conf 2>/dev/null || true
fi

section "5. Docker port publishing and subnet overlap"
DOCKER=()
if have docker; then
  if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
  elif sudo -n docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
  else
    echo "[INFO] Docker exists, but current user cannot query the daemon"
  fi
fi

if ((${#DOCKER[@]})); then
  "${DOCKER[@]}" ps --format 'table {{.Names}}\t{{.Ports}}' || true
  host_routes="$( { ip -o -4 route show 2>/dev/null; ip -o -6 route show 2>/dev/null; } |
    awk '$1 ~ /\// {print $1}' | sort -u | tr '\n' ' ')"

  while IFS= read -r net_id; do
    [[ -n "$net_id" ]] || continue
    details="$("${DOCKER[@]}" network inspect "$net_id" \
      --format '{{.Name}}{{range .IPAM.Config}} {{.Subnet}}{{end}}' 2>/dev/null || true)"
    read -r net_name subnet_list <<<"$details"
    [[ -n "${subnet_list:-}" ]] || continue
    for subnet in $subnet_list; do
      echo "Docker network: ${net_name} (${subnet})"
      python3 - "$subnet" "$net_name" "$host_routes" <<'PY'
import ipaddress
import sys

docker_net = ipaddress.ip_network(sys.argv[1], strict=False)
name = sys.argv[2]
for route in sys.argv[3].split():
    try:
        host_net = ipaddress.ip_network(route, strict=False)
    except ValueError:
        continue
    if docker_net.version == host_net.version and docker_net.overlaps(host_net):
        print(f"[WARN] Docker network {name} ({docker_net}) overlaps host route {host_net}")
PY
    done
  done < <("${DOCKER[@]}" network ls -q 2>/dev/null || true)
else
  echo "[INFO] Docker subnet inspection skipped"
fi

section "6. Task-2 style checks (bind, publish, route-to-client)"
# Bind must be 0.0.0.0 (or expected iface), not only 127.0.0.1.
if have ss; then
  ss -tlnp | grep -E ":${APP_PORT}\\b" || echo "[INFO] nothing listening on :${APP_PORT}"
fi
if ((${#DOCKER[@]})); then
  while IFS= read -r cname; do
    [[ -n "$cname" ]] || continue
    echo "docker port ${cname}:"
    "${DOCKER[@]}" port "$cname" 2>/dev/null || true
  done < <("${DOCKER[@]}" ps --format '{{.Names}}' 2>/dev/null || true)
fi
CLIENT_IP="${CLIENT_IP:-}"
if [[ -n "$CLIENT_IP" ]]; then
  echo "ip route get ${CLIENT_IP}:"
  ip route get "$CLIENT_IP" 2>/dev/null || true
else
  echo "[INFO] Set CLIENT_IP=x.x.x.x to run: ip route get <client>"
fi

section "7. Suggested remote checks"
cat <<'EOF'
Order for Task 2 incidents:
  1) client: curl/nc (timeout vs refused)
  2) ss -tlnp (127.0.0.1 vs 0.0.0.0)
  3) docker port CONTAINER
  4) UFW / DOCKER-USER / FORWARD / nat (watch packet counters; do not delete blindly)
  5) ip route get CLIENT_IP + Docker subnet overlap
  6) tcpdump while reproducing
  7) DNS if clients use a name
See docs/NETWORK_INCIDENT_RUNBOOK.md and docs/NETWORK_INCIDENT_CASE.md.
EOF

echo
echo "[SUCCESS] Network diagnostics completed. Findings require interpretation; no firewall rules were changed."
