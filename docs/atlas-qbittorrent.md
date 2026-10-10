# Atlas qBittorrent

Atlas runs the official qBittorrent-nox image, pinned by digest, in the
admin-owned rootless `atlas-qbittorrent.service` Quadlet. No VPN is involved:
outbound traffic uses Atlas' normal home-network default route. Existing
WireGuard configuration is unchanged.

- LAN Web UI: `http://192.168.178.55:8090` (LAN-only firewalld rule,
  already including Aegis at `192.168.178.54`).
- Prepared public domain: `torrent.fscotto.co`, through NPM on Prometheus.
  DNS and the NPM Proxy Host remain manual operations.
- Downloads: `/zpool/archive/Downloads`, available through SMB `Archive`.
- Private configuration dataset: `zpool/services/data/qbittorrent`.
- Only configuration and Downloads are mounted in the container.
- UPnP/NAT-PMP is disabled in the initial settings. No torrent peer port is
  published and no router port forwarding is configured. Outbound connections
  work; inbound peer connectivity and seeding are consequently limited.
- The Web UI keeps authentication and CSRF/Host-header protection enabled.
  Initial settings are seeded only once. Ansible owns only the declared Web
  domain, reverse-proxy support, trusted Aegis source, and authentication/CSRF/Host
  protections; it stops only qBittorrent before changing these settings and
  preserves credentials and unrelated application settings.

## Deployment

From the repository root:

```sh
ansible-playbook ansible/site.yml --limit atlas --tags qbittorrent --check --diff
ansible-playbook ansible/site.yml --limit atlas --tags qbittorrent
```

The service starts at boot through `WantedBy=default.target` and admin lingering.
A real reboot must be verified separately. Only a changed Quadlet restarts the
service on subsequent playbook runs.

## First login

Username: `admin`. The application generates a temporary password at startup.
Read it privately on Atlas, without pasting it into chat:

```sh
ssh admin@192.168.178.55 'podman logs atlas-qbittorrent 2>&1 | grep "temporary password" | tail -1'
```

Set a permanent password immediately under Web UI settings. Temporary passwords
change after restarting until a permanent password is saved. LAN access uses
HTTP; do not expose this port to the Internet. An SSH tunnel may be used instead
for encrypted access.

Downloads are inside Archive and inherit its existing snapshot, Borg and offline
USB backup scope. Large downloads and incomplete files therefore affect backup
capacity. No backup exclusions or automatic deletion are introduced.

Official image documentation:
<https://github.com/qbittorrent/docker-qbittorrent-nox>

## Verified on 2026-10-10

The pinned image reports qBittorrent v5.2.4. Targeted deployment succeeded and a
second application reported `changed=0`, `failed=0`. LAN HTTP returned 200 from
Ikaros; unauthenticated API access returned 403. Authenticated API checks verified
the download paths, required authentication, Host-header/CSRF protection, and
port forwarding disabled, including after a qBittorrent service restart. Existing
Gitea, Navidrome, Syncthing and iCloudPD services remained active.

A real torrent download and a host reboot have not been tested. The initial
WebUI port mapping was corrected to use 8090 internally and externally, preserving
Host-header validation. qBittorrent 5.2 uses `[Network] PortForwardingEnabled=false`
for its persistent UPnP/NAT-PMP option.


## Manual public endpoint setup

Atlas is prepared for `torrent.fscotto.co`, with reverse-proxy support enabled
and only `192.168.178.54` (the Aegis source-NAT gateway) trusted for forwarded
client addresses. Existing LAN access remains available. No new firewall opening
is required because the existing `192.168.178.0/24` rule includes Aegis.

Before publishing, set a strong permanent Web UI password. A temporary startup
password is not suitable for a public endpoint. Do not bypass authentication for
the reverse proxy or disable CSRF/Host validation.

Namecheap:

- Type: A Record; Host: `torrent`; Value: `179.237.102.172` (Prometheus).
- Do not point this record to Atlas' private LAN address.

NPM on Prometheus:

- Domain Names: `torrent.fscotto.co`
- Scheme: `http`
- Forward Hostname/IP: `192.168.178.55`
- Forward Port: `8090`
- SSL: request/select a certificate for the domain and enable Force SSL.
- No custom Advanced configuration is needed for the currently deployed NPM:
  its standard include sets `Host $host`, `X-Forwarded-Proto`, and
  `X-Forwarded-For`. Host has no explicit external port, avoiding the Web UI's
  internal-port validation. Do not replace it with `Host $http_host` when the
  latter includes `:443`.

Reference: <https://github.com/qbittorrent/qBittorrent/wiki/NGINX-Reverse-Proxy-for-Web-UI>.
Public DNS, TLS and end-to-end login remain unverified until the manual setup is
complete. Preparing the Web proxy does not change torrent peer connectivity.

### Reverse-proxy preparation verified on 2026-10-10

The previous live domain `downloads.fscotto.co` was verified with HTTPS forwarded headers from the NPM
container on Prometheus through Aegis (HTTP 200). Unauthenticated API access is
still denied (403), and an unrelated Host is rejected (401). No DNS record,
NPM Proxy Host, certificate, router forwarding or WireGuard configuration was
changed. The existing LAN firewall rule already permits Aegis. A permanent
Web UI password still needs to be configured before public exposure.

The domain change to `torrent.fscotto.co` was subsequently applied to Atlas with
the targeted `qbittorrent` playbook tag. The old live Host allowlist caused HTTP
401 (Unauthorized) on the new public domain. After deployment, public HTTPS
returned 200 and unauthenticated API access remained denied (403). Credentials,
Host validation and CSRF protection were preserved; all existing Atlas services
remained active. DNS and NPM were not modified by this deployment.
