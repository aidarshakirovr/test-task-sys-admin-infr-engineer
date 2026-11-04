# Network incident runbook (Docker service unreachable from clients)

Symptoms typically: container is up, app answers inside the container and on the host, but other machines get timeout or connection refused.

## Order of checks

1. **Client-side reachability** — `curl`/`nc`; note timeout vs refused.
2. **Listen address** — `ss -tlnp`; expect `0.0.0.0:PORT` not only `127.0.0.1`.
3. **Docker publish** — `docker port CONTAINER`.
4. **Firewall / NAT** — UFW, `DOCKER-USER`, FORWARD, nat; watch counters; no blind deletes.
5. **Routing / overlap** — `ip route get CLIENT_IP` + Docker subnets.
6. **tcpdump** while reproducing.
7. **DNS** if clients use a name.

Helper: `APP_PORT=8080 bash scripts/network-diagnostics.sh`

## Hypotheses (illustrative): commands + expected symptoms

### A. Docker subnet ∩ LAN

- **Commands:** `ip route get CLIENT_IP`; `docker network inspect bridge`; compare with LAN CIDR.
- **Symptoms:** Client timeout; `ip route get` exits via `docker0`; host-local curl works.
- **Fix direction:** `default-address-pools` in daemon.json; recreate networks (maintenance window).

### B. rp_filter + asymmetric routing

- **Commands:** `sysctl net.ipv4.conf.all.rp_filter net.ipv4.conf.default.rp_filter`; `ip rule`; `ip route get` both directions.
- **Symptoms:** SYN arrives (tcpdump) but replies dropped; intermittent one-way paths.
- **Fix direction:** Adjust routing symmetry or rp_filter carefully in staging.

### C. MTU / PMTUD blackhole

- **Commands:** `ip link`; `ping -M do -s 1472 TARGET`; check ICMP fragmentation-needed filtered.
- **Symptoms:** Small HTTP works; large responses hang; TLS handshake stalls after ClientHello.
- **Fix direction:** Clamp MSS / fix ICMP path / correct tunnel MTU.

### D. Conntrack exhaustion / stale state

- **Commands:** `conntrack -L | wc -l` (if available); `dmesg | grep -i conntrack`; `sysctl net.netfilter.nf_conntrack_count`.
- **Symptoms:** New connections fail under load; old sessions misbehave after NAT change.
- **Fix direction:** Raise table size / flush specific entries; fix NAT churn.

### E. UFW forward / missing `ufw route` / DOCKER-USER

- **Commands:** `grep DEFAULT_FORWARD_POLICY /etc/default/ufw`; `ufw status verbose`; `iptables -S DOCKER-USER`.
- **Symptoms:** Host curl OK; remote timeout; FORWARD DROP counters climb.
- **Fix direction:** Persist DOCKER-USER allows (role `host_hardening`); avoid mass rule deletes.

### F. iptables-nft vs legacy

- **Commands:** `iptables -V`; `nft list ruleset | sed -n '1,80p'`; confirm only one tooling path.
- **Symptoms:** Rules “applied” but invisible to the active backend; confusing duplicates.
- **Fix direction:** Standardize on nft or legacy; re-apply via IaC.

## Safe production network changes

- Capture baseline; change in staging; one control at a time; OOB access; rollback ready.
