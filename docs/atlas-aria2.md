# Atlas HTTP downloader: aria2 + AriaNg

Ansible manages two admin-owned rootless Quadlets, `atlas-aria2.service` and
`atlas-ariang.service`, with pinned images. The third-party aria2 image is used
only for its binary: its init scripts, tracker updates and automatic deletion
hooks are bypassed. The static frontend has no host-data or credential mounts.

- Web UI (LAN only): `http://192.168.178.55:8091`.
- RPC (LAN only, mandatory secret): `http://192.168.178.55:6800/jsonrpc`.
- Payloads: `/zpool/archive/Downloads`, shared with qBittorrent and SMB Archive.
- Private state: `zpool/services/data/aria2`, mounted at `/zpool/services/data/aria2`.
- The persistent 256-bit RPC secret is generated only on Atlas; it is not committed
  or printed by Ansible. It is not a username/password: AriaNg passes it as an
  RPC token. Whoever has it can control the downloader.
- No DNS/NPM/public exposure or WireGuard changes are performed. Never publish
  the bare RPC port on the Internet. LAN HTTP does not encrypt the token; use
  only a trusted LAN or an SSH tunnel.

## Deploy

From the repository root:

```sh
ansible-playbook ansible/site.yml --limit atlas --tags aria2 --check
ansible-playbook ansible/site.yml --limit atlas --tags aria2
```

Check mode validates storage and Quadlet/firewall changes but skips generation,
reading and rendering of secret-dependent configuration and runtime probes.
Boot startup uses admin lingering plus `WantedBy=default.target`; a host reboot
must be tested separately.

## First use

Open the LAN Web UI. In **AriaNg Settings -> RPC**, use:

- Protocol: HTTP (JSON-RPC)
- Host/address: `192.168.178.55`
- Port: `6800`
- Interface/path: `jsonrpc`
- Secret: privately read it in your terminal with:

```sh
ssh admin@192.168.178.55 'cat /zpool/services/data/aria2/rpc-secret'
```

Do not paste it into chat or share exported AriaNg settings, which may include
it. After saving settings the status should be Connected. Select **New**, add
one or more actual file URLs and start the download. One download/connection at
a time is the default, to reduce load and avoid excessive requests to Apple.

The UI may store the secret in browser-local settings. There is no additional
login for the static page; the RPC token protects the actual service. Do not
publish this interface on the qBittorrent endpoint (`torrent.fscotto.co`).

## Interrupted downloads and iCloud

The queue is saved every 30 seconds and on graceful shutdown. Keep both partial
payloads and `.aria2` control files for resume. Restarting restores pending tasks.
Resume requires server support and a valid link. Expired Apple links must be
refreshed; some downloads also require authenticated cookies or headers. Never
share full signed URLs or cookie files. Apple exports have not been tested until
new links are available. TLS certificate verification remains enabled.

No completion/error deletion hooks are enabled. Cancelling a task does not
implicitly clean payloads. Downloads remain inside the existing Archive backup
scope, including incomplete files. Session files contain URLs and are kept
private; their dataset inherits existing recursive backup/snapshot coverage.

References:
- <https://github.com/aria2/aria2>
- <https://github.com/mayswind/AriaNg>
- <https://github.com/P3TERX/Aria2-Pro-Docker>

## Verified on 2026-10-10

The pinned aria2 binary reports 1.36.0. The Web UI and authenticated RPC are
operational; RPC requests without a token are rejected. A second targeted
Ansible application reported `changed=0`, `failed=0`.

A real HTTPS smoke test downloaded the official curl 8.10.1 source archive
(2,726,748 bytes). After pausing at 1,048,576 bytes and restarting only
`atlas-aria2.service`, the saved task and partial progress were restored. The
completed file matched an independently downloaded reference by SHA-256.
Only the exact smoke-test task and its temporary payload/control files were
removed. A host reboot and authenticated Apple export downloads are not claimed.
