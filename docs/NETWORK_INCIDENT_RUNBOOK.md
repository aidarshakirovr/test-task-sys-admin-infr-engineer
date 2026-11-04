# Network incident runbook (Docker service unreachable from clients)

Symptoms typically: container is up, app answers inside the container and on the host, but other machines get timeout or connection refused.

## Order of checks

1. **Client-side reachability**
   - From an affected client: `curl -v --connect-timeout 5 http://SERVER_IP:PORT/` and/or `nc -vz SERVER_IP PORT`.
   - Record whether the failure is **timeout** (filtered/blackhole/routing) or **refused** (nothing listening on that path).

2. **Listen address on the server**
   - `ss -tlnp | grep PORT`
   - Confirm bind is `0.0.0.0:PORT` (or the expected interface), not only `127.0.0.1:PORT`.

3. **Docker publish mapping**
   - `docker port CONTAINER`
   - `docker inspect CONTAINER --format '{{json .HostConfig.PortBindings}}'`
   - Confirm host IP/port mapping matches what clients use.

4. **Firewall and Docker chains (read counters, do not delete blindly)**
   - `ufw status verbose`
   - `iptables -L FORWARD -n -v --line-numbers`
   - `iptables -S DOCKER-USER`
   - `iptables -t nat -L DOCKER -n -v --line-numbers`
   - Prefer one scoped change with a tested rollback. Do **not** mass-delete “contradictory” rules.

5. **Routing and Docker subnet overlap**
   - `ip route get CLIENT_IP`
   - Compare host routes with Docker networks (`docker network inspect` / `scripts/network-diagnostics.sh`).
   - Overlap with LAN (classic `172.17.0.0/16`) is fixed via `/etc/docker/daemon.json` `default-address-pools` (see role `host_hardening`), then recreate networks.

6. **Packet capture**
   - While reproducing from the client: `tcpdump -ni any host CLIENT_IP and port PORT`
   - Decide if SYN arrives, if SYN-ACK leaves, or if traffic is dropped on FORWARD/NAT.

7. **DNS (if clients use a name)**
   - From the client: resolve the name and compare with the expected server IP.
   - Wrong DNS can look like a “network change” incident.

8. **Additional hypotheses (not only Docker∩LAN)**
   - `rp_filter=1` + asymmetric routing dropping return traffic.
   - MTU / PMTUD blackhole (large responses fail; try smaller MSS or check ICMP fragmentation-needed).
   - Conntrack table full / stale entries (`conntrack -L` / dmesg).
   - UFW `DEFAULT_FORWARD_POLICY=DROP` without `ufw route` / DOCKER-USER allowances.
   - `iptables-nft` vs legacy mismatch after mixed tooling.

## Safe production network changes

- Capture baseline (`ip addr`, `ip route`, `iptables-save` / nft, Docker daemon.json).
- Change in staging first; ship via IaC.
- Keep console/out-of-band access.
- Change one control at a time; verify from a second host; keep rollback ready.
- Helper (read-only): `bash scripts/network-diagnostics.sh`
