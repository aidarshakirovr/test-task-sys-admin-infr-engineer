# Task 2 case analysis: Docker subnet overlapping the LAN

## Symptom

- Container is running; the app answers inside the container and on the host.
- Clients on other machines get timeout (or refuse) when connecting to the published port.

Root cause in this incident class: **Docker bridge subnet overlapped the site LAN** (classic default `172.17.0.0/16` colliding with the on-site network). Return traffic to clients was routed into the Docker bridge instead of the physical LAN.

## Example diagnostic trail (illustrative)

Values below are representative of the investigation order. They are not a live capture from production.

### 1. Client

```text
$ curl -v --connect-timeout 5 http://192.168.10.15:8080/
* Trying 192.168.10.15:8080...
* Connection timed out
```

Timeout ⇒ packets likely dropped/blackholed on the path (not a local bind-only refuse).

### 2. Listen sockets on the server

```text
$ ss -tlnp | grep 8080
LISTEN 0  4096  0.0.0.0:8080  0.0.0.0:*  users:(("docker-proxy",pid=2211,fd=4))
```

Bind is `0.0.0.0:8080` (not only `127.0.0.1`).

### 3. Docker publish

```text
$ docker port web-service-prod
80/tcp -> 0.0.0.0:8080
```

### 4. Firewall / NAT counters (read, do not delete)

```text
$ iptables -L FORWARD -n -v --line-numbers | sed -n '1,12p'
Chain FORWARD (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source       destination
1     1204  88K  DOCKER-USER  all  --  *      *       0.0.0.0/0    0.0.0.0/0
2      980  70K  DOCKER-ISOLATION-STAGE-1  all -- * * 0.0.0.0/0 0.0.0.0/0
...
$ iptables -t nat -L DOCKER -n -v --line-numbers
...
DNAT  tcp  --  *  *  0.0.0.0/0  0.0.0.0/0  tcp dpt:8080 to:172.17.0.2:80
```

Counters move on host-local tests; client SYNs may still fail if routing is wrong.

### 5. Route to client vs Docker overlap

```text
$ ip route get 192.168.10.50
192.168.10.50 dev docker0 src 172.17.0.1 uid 0
    cache

$ ip -4 route | grep 172.17
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1

$ ip -4 addr show | grep '192.168.10'
inet 192.168.10.15/24 ...
```

LAN is `192.168.10.0/24`, but `ip route get` selected `docker0` because the Docker network overlapped (or shadowed) the return path. In many sites the overlap is literal (`172.17.0.0/16` used both as LAN and Docker).

### 6. Fix direction

Set non-colliding pools in `/etc/docker/daemon.json` (role `host_hardening`):

```json
{
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ]
}
```

**Important:** pools apply only to **new** networks. Restarting Docker stops containers (maintenance window). Recreate existing overlapping networks manually, then re-check `ip route get <client>`.

Also check: `rp_filter`, MTU/PMTUD, conntrack, UFW forward policy / `ufw route`, iptables-nft vs legacy — see runbook §8.

See also `docs/NETWORK_INCIDENT_RUNBOOK.md` and `scripts/network-diagnostics.sh`.
