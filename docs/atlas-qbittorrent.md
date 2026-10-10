# Atlas qBittorrent

Atlas runs the official qBittorrent-nox image, pinned by digest, in the
admin-owned rootless `atlas-qbittorrent.service` Quadlet. No VPN is involved:
outbound traffic uses Atlas' normal home-network default route. Existing
WireGuard configuration is unchanged.

- LAN Web UI: `http://192.168.178.55:8090` (LAN-only firewalld rule).
- Downloads: `/zpool/archive/Downloads`, available through SMB `Archive`.
- Private configuration dataset: `zpool/services/data/qbittorrent`.
- Only configuration and Downloads are mounted in the container.
- UPnP/NAT-PMP is disabled in the initial settings. No torrent peer port is
  published and no router port forwarding is configured. Outbound connections
  work; inbound peer connectivity and seeding are consequently limited.
- The Web UI keeps authentication and CSRF/Host-header protection enabled.
  Initial settings are seeded only once, preserving passwords and settings
  subsequently changed in the application.

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
