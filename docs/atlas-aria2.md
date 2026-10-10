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

## Public access: downloads.fscotto.co

NPM on Prometheus manages the public endpoint separately from the Atlas
playbook. Atlas' existing LAN rules already admit the Aegis gateway; do not
publish port 6800 on the router or Prometheus firewall.

Create an NPM Access List before enabling the Proxy Host:

- Add a unique username and strong password in the Authorization tab.
- Leave Satisfy Any and Pass Auth to Host disabled. Do not add an IP-based
  authentication bypass.
- Keep these credentials private; they are separate from the aria2 RPC secret.

Create the Proxy Host with that Access List selected:

- Domain: `downloads.fscotto.co`; DNS A record points to `179.237.102.172`.
- Scheme: HTTP; Forward Host: `192.168.178.55`; Forward Port: `8091`.
- Custom Location `/jsonrpc`: HTTP, `192.168.178.55`, port `8092` (private gateway).
  Leave its forwarding path unchanged so `/jsonrpc` reaches aria2.
- Request a Let's Encrypt certificate and enable Force SSL.
- Use HTTPS JSON-RPC (POST) in AriaNg: host `downloads.fscotto.co`, port `443`,
  path `jsonrpc`, with the RPC secret field empty. Never embed either secret in
  URLs or static frontend files.

Use NPM's Custom Locations UI rather than a hand-written unprotected location:
the deployed NPM templates include Access List authentication in both the
default location and custom locations. Verify this in the rendered host config.
Both `/` and `/jsonrpc` must return 401 without proxy credentials; direct aria2
RPC on port 6800 still requires its separate token. Validate before considering public
access complete.

On 2026-10-10 NPM-to-AriaNg connectivity returned HTTP 200. After operator
creation of the Access List and saving the Proxy Host, public DNS resolved to
Prometheus and valid HTTPS returned 401 with a Basic authentication challenge
for both `/` and `/jsonrpc`. The rendered NPM configuration confirmed both
locations use the same Access List, with Satisfy All and no upstream forwarding
of Basic credentials. Authenticated browser/RPC operation remains to be
confirmed by the operator; no passwords were read or reset.

### Server-side token gateway

`atlas_aria2_gateway_enabled` enables the Ansible-managed admin user service
`atlas-aria2-gateway.service` (tag `aria2_gateway`). Python's installed standard
library implements HTTP JSON-RPC POST, batch and `system.multicall`; WebSocket,
JSONP and XML-RPC are not supported. It reads the existing private `rpc-secret`
only on Atlas and inserts it into RPC parameters. It filters credential-bearing
response fields and rejects RPC security-option edits. Requests have size,
timeout and concurrency limits; bodies and URLs are not logged.

The adapter binds Atlas' LAN IP on port 8092 and admits only Aegis through
firewalld. Application checks admit Aegis and Atlas itself (local validation),
require the declared public Host and reject foreign browser Origins. Its
security boundary relies on Aegis and the authenticated NPM Custom Location:
never open this adapter to the whole LAN or create an unauthenticated proxy
route to it. It does not independently authenticate NPM users.

On each browser, use HTTPS `downloads.fscotto.co:443/jsonrpc`, POST and an empty
RPC secret. The normal NPM username/password login remains required. Direct LAN
clients using port 6800 still need the token. No token is embedded in static
AriaNg assets, URLs or NPM configuration.

Validation: `python3 -B tests/test_aria2_rpc_gateway.py`; then
`ansible-playbook ansible/site.yml --limit atlas --tags aria2_gateway`.

Gateway deployment on 2026-10-10 passed syntax/check validation and a second
steady-state run reported `changed=0`, `failed=0`. Six offline regression tests
passed. From the NPM container, token-free multicall returned version and global
stats; an Atlas-local batch verified credential response filtering. Foreign
Origins returned 403, direct Ikaros-to-gateway access was blocked, and both
public UI and RPC remained 401 without Basic credentials. NPM host 16 now
forwards `/jsonrpc` to 8092 with the same Access List. `nginx -t` passed;
aria2, AriaNg, gateway and qBittorrent remained active. Public authenticated
browser operation and an actual host reboot remain operator verification.

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
