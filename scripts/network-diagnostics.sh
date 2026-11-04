#!/usr/bin/env bash
set -euo pipefail

TARGET_PORT="${1:-8080}"
echo "=========================================================="
echo " Starting Network Diagnostics for Port :${TARGET_PORT}"
echo "=========================================================="

echo -e "\n[1] Checking Socket Listeners (ss -tulpn):"
LISTEN_INFO=$(ss -tulpn \vert{} grep ":${TARGET_PORT} " || true)
if [ -z "${LISTEN_INFO}" ]; then
    echo "[-] CRITICAL: No process listening on port ${TARGET_PORT}."
else
    echo "[+] Found listener:"
    echo "${LISTEN_INFO}"
    if echo "${LISTEN_INFO}" \vert{} grep -q "127.0.0.1:${TARGET_PORT}"; then
        echo "[!] ROOT CAUSE: Port is bound exclusively to 127.0.0.1 (Loopback)!"
    fi
fi

echo -e "\n[2] Checking Kernel IP Forwarding:"
IP_FW=$(sysctl -n net.ipv4.ip_forward)
if [ "${IP_FW}" -eq 1 ]; then
    echo "[+] OK: net.ipv4.ip_forward = 1 (Routing enabled)"
else
    echo "[-] CRITICAL: net.ipv4.ip_forward = 0"
fi

echo -e "\n[3] Checking Docker NAT Chain (iptables -t nat):"
if sudo iptables -t nat -L DOCKER -n -v | grep -q "${TARGET_PORT}"; then
    echo "[+] OK: Found DNAT rule for port ${TARGET_PORT}"
else
    echo "[!] WARN: No DNAT entry found in DOCKER chain"
fi

echo "=========================================================="
echo " Diagnostics Completed"
echo "=========================================================="
