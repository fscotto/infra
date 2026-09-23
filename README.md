# Infra — Personal Infrastructure as Code

> **Italian version:** [README.it.md](README.it.md)

This is my Ansible repo for keeping my personal machines and dotfiles in sync. It is the source of truth for packages, services, and user configuration. The setup is meant to stay modular, reproducible, and idempotent without getting too clever.

## Layout

```text
infra/
├── ansible/
│   ├── site.yml
│   ├── inventory/
│   │   ├── hosts.yml
│   │   ├── group_vars/
│   │   └── host_vars/
│   ├── templates/
│   └── roles/
├── dotfiles/
│   ├── common/
│   ├── desktop/
│   ├── fedora/
│   ├── server/
│   ├── workstation/
│   ├── workstation_dev_wsl/
│   └── nymph/
├── scripts/
├── secrets/
├── README.md
└── README.it.md
```

- `ansible/` holds provisioning and host configuration.
- `dotfiles/` holds versioned user configuration.

## Managed machines

The repo currently covers Fedora/GNOME desktops, one Fedora WSL workstation, a Fedora IoT LAN
node, a Rocky Linux 9 server, and a Rocky Linux 9 NAS. Configuration is layered instead of being tied
to host names:

```text
common user environment
+ platform-specific setup
+ role-specific software
+ independently selected desktop
+ host overrides
```

| Host | Platform | Role | Desktop |
| --- | --- | --- | --- |
| `ikaros` | Fedora | Personal workstation | GNOME |
| `nymph` | Fedora | Desktop laptop | GNOME |
| `deadalus` | Fedora WSL | Development workstation | — |
| `aegis` | Fedora IoT | Always-on LAN node | — |
| `prometheus` | Rocky Linux | Server | — |
| `atlas` | Rocky Linux | NAS | — |

```text
ikaros must be boring
nymph is allowed to break
```

`ikaros` is the stable personal Fedora/GNOME desktop. `nymph` is the laptop and gets the same shared desktop dotfiles while GNOME itself stays close to the Fedora defaults. The legacy `void` and `desktop` groups are compatibility parents; the main axes are `platform_*`, `role_*`, and `desktop_*`.

The official ChatGPT desktop RPM is enabled only on `ikaros` and `nymph`. The
playbook configures OpenAI's signed RPM repository and imports its pinned RPM
signing key before installation; subsequent updates are handled by DNF.

## Deferred planned node: Cerberus

`cerberus` is a **postponed** management-plane node, pending the physical setup
of the office in the new house. It is not yet an inventory host and no role or
playbook targets it.

The planned hardware is a Lenovo ThinkCentre M700 Tiny (Intel Core i3-6100T,
8 GB RAM, and a 256 GB SSD) with native 1 Gbps Ethernet. It will share Ikaros'
monitor and peripherals through a multi-input KVM switch, using a passive
DisplayPort-to-HDMI cable for its video connection. Fedora Sericea, the
immutable Fedora variant with the Sway Wayland compositor, is the intended
operating system.

Cerberus will be an isolated management plane: Ansible will run from a
dedicated Toolbox environment to provision the future `uranus` cluster, rather
than from Ikaros or an unmanaged host. Its rootless Podman observability stack
will run Grafana, Prometheus, and Loki. The local SSD is the hot tier and
retains metrics and logs for 30 days; scheduled exports will place older
historical data on an NFS-mounted Atlas dataset as the cold tier. The detailed,
implementation-gated plan is maintained in `AGENTS.md`.

## Desktop profiles

- `ikaros`: stable Fedora Workstation + GNOME desktop.
- `nymph`: Fedora Workstation + GNOME laptop.
- Void desktops stay available as reusable future profiles through `platform_void + graphical_desktop`.

Void uses `desktop_environment: minimal`. Sway is the normal session; add a host to `desktop_niri` to select Niri. GNOME is only handled on Fedora through `desktop_gnome`.

The desktop setup includes shared desktop dotfiles, Sway/Niri support for future Void hosts, `emptty`, `turnstile` user services, a stable ssh-agent socket at `~/.local/state/ssh-agent/socket`, Emacs authoring config, tmux bootstrapped through TPM, Flatpak, GNOME Keyring, Udiskie, and `kanshi` for Sway multi-monitor setups.

Void package buckets stay separate on purpose:

- `void_packages_base`: system runtime and services.
- `desktop_common_packages`: shared GUI infrastructure.
- `desktop_minimal_packages`: GTK applications and `emptty`.
- `desktop_sway_packages`: Sway-only binaries.

## Workstation

`deadalus` is the only workstation target. It is Fedora running in WSL on the Windows machine with the same name. Flatpak and Snap are explicitly kept out of this profile.

The workstation receives two layers:

- Fedora development setup through `workstation_dev_fedora`.
- WSL setup with `systemd` through `workstation_dev_wsl`.

That gives it Fedora packages through DNF, Docker from the official repository, Mise from its official COPR repository with a pinned Eclipse Temurin Java 11 JDK, shared workstation dotfiles and templates, tmux helpers, and WSL systemd configuration. Windows applications are installed manually; the WSL profile does not manage Python remoting components for them.

### WSL workflow

1. Start Fedora WSL once and finish creating the Linux user.
2. Install Ansible inside Fedora WSL.
3. Run the playbook from that distribution with `--limit deadalus`.
4. Use Windows-side VS Code with Remote WSL, Remote SSH, and Dev Containers if wanted.

## Server

`prometheus` is the Rocky Linux 9 server. It has no graphical environment and gets server-specific
dotfiles and templates. The profile provisions configuration only: it does not transfer data, start
the Compose stack, update DNS, or perform a cutover.

The server profile installs platform-specific packages, Podman and podman-compose, declared systemd
services, and firewalld. The manually activated `podman-compose-server` unit contains the existing
Nginx Proxy Manager and Gitea services. The desired Compose file no longer includes Navidrome,
Syncthing, or the obsolete Navidrome PostgreSQL database; their temporary Atlas deployment is managed
by `profile_backend_phase1`. Applying the profile does not stop or remove legacy containers and does
not delete `/opt/postgres/data`.

Firewalld enables SSH, Cockpit (`9090/tcp`), HTTP and HTTPS. Nginx Proxy Manager publishes only
`80/tcp` and `443/tcp`; its administration interface is bound to `127.0.0.1:81` and can be reached
from Ikaros or Nymph with the `npm-tunnel` Bash alias. Nextcloud remains disabled and the profile
does not provision any `/srv/nextcloud` directories.

NPM remains managed only by `profile_server`. Its WireGuard peer is Aegis (`10.0.0.2`), which forwards
selected requests to LAN addresses and source-NATs them so no static route is required on the router.
Use an Atlas LAN address for any current NAS-backed upstream; when Uranus receives its VIP, add that VIP
to Prometheus' Aegis peer `AllowedIPs` and declare the corresponding proxy target separately.

Server identity comes from `server_username`, `server_user_group`, and `server_user_home` in `ansible/inventory/group_vars/server.yml`. `server_username` defaults to `username`, but it can be overridden, for example:

```bash
ansible-playbook ansible/site.yml --limit prometheus -e server_username=myuser
ansible-playbook ansible/site.yml --limit prometheus \
  -e server_username=myuser -e server_user_group=mygroup \
  -e server_user_home=/srv/myuser
```

The target must already provide `server_username` with local sudo access.
Prometheus authorizes its declared SSH public keys through separate files below
`~/.ssh/authorized_keys.d/`, while `sshd` is configured to read those files directly.

### DuckDNS

`profile_server` renders `~/duckdns/duck.sh` with mode `0700`, keeping the existing updater path
and `duck.log`. Set `server_duckdns_domain` in the server's host vars and store the **rotated**
`vault_duckdns_token` in encrypted `secrets/vault.yml` (using `ansible-vault edit secrets/vault.yml`)
or untracked `secrets/vault.local.yml`. Never commit the rendered script or put the token on a
command line. Rendering hides secret output/diffs; the updater verifies TLS and passes the token
to curl through stdin. The playbook neither runs the updater nor changes its external schedule.

```bash
ansible-playbook ansible/site.yml --limit prometheus --tags duckdns --check --diff
ansible-playbook ansible/site.yml --limit prometheus --tags duckdns
```

An exposed token must be revoked/regenerated on DuckDNS: deleting it from Git history does not
revoke it. After a history cleanup, re-clone other checkouts rather than merging the old history
back in; preserve any uncommitted work separately without copying secrets.

### Data migration

Provision Rocky first, then run the migration script **on the retired Ubuntu source host**. It is
dry-run by default and requires an explicit source-stack stop before it can copy application data:

```bash
sudo ./scripts/migrate_prometheus_data.sh \
  --destination rocky@179.237.102.172 \
  --identity /root/.ssh/id_ed25519

sudo ./scripts/migrate_prometheus_data.sh \
  --destination rocky@179.237.102.172 \
  --identity /root/.ssh/id_ed25519 \
  --quiesce-source --execute
```

The script copies only Nginx Proxy Manager and Gitea data. It does not delete data, move
Navidrome/Syncthing, copy `/home/git/.ssh`, start containers, update DNS, or perform a cutover. The
destination SSH host key must already be trusted and the destination account needs passwordless sudo
for `rsync`. It preserves ACLs but not extended attributes, so source SELinux labels are not
transferred; the Rocky Compose bind mounts apply their own `:Z` labels when containers start.

## DNS Filter

`aegis` is a Raspberry Pi 4 running Fedora IoT. Generate Ignition from
`ansible/bootstrap/aegis.bu` with the included Podman/Butane helper, then write the SD card with
`arm-image-installer`:

```bash
ansible/bootstrap/generate-aegis-ign.sh --write IMAGE DEVICE
```

The controller manages it remotely as `pi@aegis`; unlike local desktop profiles, Aegis is
intentionally an SSH inventory target. `profile_aegis` manages rootful Podman Quadlets for AdGuard
Home and iCloudPD, persistent data under `/var/lib`, the Podman auto-update timer, LAN-restricted
firewalld rules, SSH key-only access for `pi`, the `nfs-utils` and `wireguard-tools` rpm-ostree layers,
and `wake-ikaros`. `wireguard_overlay` makes Aegis the internal endpoint and LAN gateway for Prometheus:
it enables persistent IPv4 forwarding, installs a scoped WireGuard-to-LAN firewalld policy, and source-NATs
forwarded tunnel traffic so the router needs no static route. A new layered package deployment requires a manual reboot; the
role reports this condition but never reboots Aegis automatically. Set the host-local
`aegis_lan_subnet`, `aegis_adguard_web_port`, and `aegis_network_connection_uuid` values before
applying it. The playbook permits
AdGuard Home HTTP on port `80`; the initial wizard port `3000` is intentionally unmanaged and must be
opened and closed manually during initial setup. The profile disables the local systemd-resolved DNS
stub and points `/etc/resolv.conf` to its full resolver data, freeing port 53 for AdGuard. LAN clients
may use AdGuard on Aegis, while Aegis itself uses the independent upstream DNS declared by
`aegis_host_dns_servers`; this prevents Greenboot from depending on the AdGuard container during
startup. Reboot Aegis after changing its NetworkManager DNS profile. Define
`vault_aegis_icloudpd_apple_id` in Vault before applying it. iCloudPD still requires interactive MFA
initialization after its first deployment.

New Aegis images create the `admin` account in Butane. Before configuring a newly imaged node, run its
first playbook execution with `-e ansible_user=admin`; the SSH hardening role then permits that same
account. Keep the inventory on `pi` until the existing node has been replaced.

Validate the profile before deployment:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit aegis --check --diff --ask-become-pass
```

Apply only the independent host DNS configuration, then reboot Aegis manually:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit aegis --tags dns --ask-become-pass
```

Layer the Aegis NFS and WireGuard client tools independently, then reboot Aegis manually when the role reports
that the new deployment is ready:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit aegis --tags nfs --ask-become-pass
```

## NAS

`atlas` is a Rocky Linux 9 NAS reached through SSH. Normally its pool already exists and the profile
only manages child datasets. A one-time RAIDZ2 bootstrap is available only with explicit confirmation
(`atlas_create_pool=true`) and exactly four verified `/dev/disk/by-id/...` paths in `atlas_zpool_disks`.
It never partitions, forces, destroys, rolls back, or changes the vdev layout of an existing pool. Linux
clients use NFSv4 and Windows/WSL clients use SMB; both are restricted to the configured LAN.

For the first run, provide `vault_atlas_admin_password_hash`, `vault_atlas_samba_password`, and
`vault_atlas_immich_db_password`. Bootstrap the host through its
existing administrator. The explicit pool gate is safe to repeat: the role creates the RAIDZ2 pool only when
it is absent. Atlas no longer participates in the WireGuard overlay; its old interface is retired manually only after
Prometheus and Aegis have completed the replacement handshake.

`vault_atlas_admin_password_hash` must be an `/etc/shadow`-compatible hash, not a clear-text
Cockpit password. Subsequent runs use `atlas_admin_username`. Atlas declares storage, sharing, and its
LAN firewall rules enabled. Before the first apply, check the existing pool and mountpoints, LAN subnet,
and active firewalld zone. `atlas_manage_media_stack` remains disabled until `/dev/dri`, the container
paths, and the Immich database secret are validated. Atlas reads its declared SSH public keys from
separate files below `~/.ssh/authorized_keys.d/`.

With storage management enabled, Atlas creates the complete dataset hierarchy below the existing or
explicitly bootstrapped `zpool`: SMB-shared `archive`, private `services/data` with separate
`services/data/navidrome` and `services/data/syncthing` application datasets, `media`, `media/music`,
`media/photobook`, and `backup/hosts/prometheus`. Application/archive datasets use `zstd`, while media,
Syncthing, and host-backup datasets use `lz4`; `backup` has a `500G` reservation covering its descendants.
Atlas enforces targeted SELinux persistently and reports, without initiating, any reboot required to activate it. It assigns its primary LAN interface explicitly to the managed firewalld zone and applies persistent kernel network hardening: redirects and source routes are rejected, martians logged, reverse-path filtering remains loose for WireGuard, and IPv4 forwarding is disabled. SSH permits only the declared administrator using public-key authentication; root login, passwords,
agent and remote forwarding are disabled, while local forwarding remains available for private administrative tunnels. SMB3 exposes `Archive` only to the configured Vault-backed
Samba accounts on encrypted, signed SMB3 over TCP/445 only and admits the configured LAN without host-specific
exclusions. NFSv4 exports only `media/photobook` to the configured Aegis IP over TCP/2049, using
`all_squash` with anonymous UID/GID `1100`.

The `immich` system account is fixed to UID/GID `1100`, has no login shell or `wheel` membership, and
receives `video` and `render` access. The rootful Immich Server, ML, Redis-compatible cache, PostgreSQL,
and NPM Quadlets share one Podman network. Immich runs as `1100:1100`; Server and ML receive `/dev/dri`,
and Photobook is mounted read-only at `/external/photobook`. NPM publishes ports `80` and `443`; its
administration interface remains restricted to `127.0.0.1:81` for SSH-tunnel access.

Atlas temporarily hosts rootless Navidrome and Syncthing until Uranus replaces them. They bind only to
Atlas' LAN address (`192.168.178.55`); WireGuard remains exclusively between Prometheus (`10.0.0.1`)
and Aegis (`10.0.0.2`). Their state is initialized ex novo in `/zpool/services/data/navidrome` and
`/zpool/services/data/syncthing`; no source application state is migrated. The music library at
`/zpool/media/music` is populated separately.

The separate `wireguard_overlay` role manages `wg0` between Prometheus (`10.0.0.1`) and Aegis
(`10.0.0.2`), generating private keys once on their respective hosts and exchanging only public keys
through Ansible. Prometheus alone opens `51820/udp`. Aegis forwards only the declared overlay-to-LAN
traffic and source-NATs it, so Atlas and future Uranus nodes require neither a VPN interface nor a router
static route. Atlas permits Navidrome (`4533/tcp`) and the Syncthing GUI (`8384/tcp`) only from Aegis;
Syncthing native ports are limited to the LAN. Configure NPM manually with
`http://192.168.178.55:4533` and `http://192.168.178.55:8384` after the services are healthy.
Prometheus' peer includes the LAN subnet in `AllowedIPs`; add the Uranus VIP there when it exists.
When the WireGuard zone is created, Ansible reloads firewalld and immediately reloads Prometheus'
rootful Podman networks so the existing proxy stack retains container DNS and connectivity.

Validate the gateway with:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit prometheus,aegis --tags wireguard --check --diff
```

The first real WireGuard run must include both peers. If Fedora IoT has just layered `wireguard-tools`,
reboot Aegis manually and rerun the command without `--check`; the role then waits for a real peer
handshake.

Atlas declares recursive, systemd-timed ZFS snapshots for the complete pool hierarchy: 24 hourly
snapshots at minute 05, 30 daily snapshots at 00:15, 8 weekly snapshots on Sunday at 01:00, and 12
monthly snapshots on the first day at 02:00. The retention helper prunes only snapshots carrying its
managed `atlas-auto` prefix and never rolls back a dataset. The OpenZFS monthly scrub timer is scheduled
for the first Sunday at 03:00; the conflicting weekly scrub timer is disabled explicitly. The first recursive
hourly snapshot completed successfully on Atlas; retention pruning and the first scheduled scrub still await
live runtime evidence. Validate this layer independently with:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags snapshots,scrub --check --diff
```

Atlas also declares an encrypted Borg backup to the dedicated Hetzner Storage Box sub-account
`u660064-sub1`. The repository is the sub-account-relative `./borg-data` path and uses the explicitly
selected remote Borg 1.4 binary over SSH port 23. The ED25519 server key is pinned; a dedicated client
key is generated for the locked, non-login `borg` system account, and its private half never leaves
`/etc/atlas-borg`. The account has no sudo or supplementary groups and owns only its SSH identity,
passphrase, cache, and Borg state. Borg receives its passphrase through a mode `0600` file rendered from
`vault_atlas_borg_passphrase`.

The daily backup starts at 04:30 with up to 30 minutes of randomized delay. It creates a temporary,
recursive ZFS snapshot and reconstructs every dataset below `/zpool` as a read-only bind-mounted tree,
so parent and child datasets enter one consistent Borg archive. Cleanup always removes the temporary
mounts and managed snapshot. Only the root wrapper performs snapshot and mount operations; it launches
the Borg client as `borg` with temporary read-search capability and no ZFS, sudo, or pool-management
privileges. Borg retains 30 daily, 8 weekly, and 12 monthly archives, then compacts the standard
read-write repository. A full metadata and repository check runs as `borg` on the fifteenth day of each
month at 06:00. Both operations use a common lock, journal logging, and bounded systemd retries.
New backup runs also log the create phase and a compact progress line at most once per minute: dataset,
files processed, and original/compressed/deduplicated bytes. Progress lines omit individual filenames
and a percentage, since Borg does not know the total in advance; warnings may still name affected files.
Follow the current run with
`sudo journalctl -fu atlas-borg-backup.service` on Atlas; changes to the helper do not alter a run
already in progress.

Initial activation remains explicit:

1. Add a strong unique `vault_atlas_borg_passphrase` with `ansible-vault edit secrets/vault.yml`.
2. Generate and display only the dedicated public key with
   `ansible-playbook ansible/site.yml --limit atlas --tags borg_key`.
3. Install that public key in the Hetzner sub-account, then apply with
   `ansible-playbook ansible/site.yml --limit atlas --tags packages,borg`.
4. Copy the ignored `secrets/recovery/atlas-borg-repokey.export` file to genuinely offline storage.
   The controller-side copy is not an offline backup by itself.

The role initializes only the missing `repokey` repository and never accepts an unpinned host key or
password authentication. It does not start the first backup manually. Validate the rendered state with:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags packages,borg --check --diff
```

Atlas runtime activation is complete: the initial backup and repository check succeeded, a full restore
to a temporary directory was validated against the live `Archive` tree, the recovery-key export was copied
to offline storage, and the temporary snapshot and bind mounts were cleaned up.

A temporary Nextcloud deployment on Atlas is also planned before Uranus: it requires separately
declared persistent application, database, and cache storage, Vault-backed credentials, NPM-only
publishing through Aegis, and defined backup, upgrade, and eventual migration procedures. Do not deploy
it before the data-protection checklist is complete.

Prometheus backup pulls, USB backup, monitoring, and disaster-recovery tests remain follow-up work. The
prioritized operational backlog is kept in `AGENTS.md`.

## How layering works

A host can intentionally belong to more than one inventory group. The final configuration is the combination of the host and its groups, not a one-host/one-play mapping.

```text
common configuration
+ platform configuration
+ role configuration
+ desktop configuration
+ host overrides
```

Current examples:

```text
ikaros   -> common + platform_fedora + role_personal_workstation + graphical_desktop + desktop_gnome + ikaros
nymph    -> common + platform_fedora + graphical_desktop + desktop_gnome + nymph
deadalus -> common + platform_fedora + workstation_dev_fedora + workstation_dev_wsl + deadalus
```

This keeps shared configuration reusable, lets host overrides stay small, and leaves the Void desktop profile ready for a future host using `platform_void + graphical_desktop + desktop_sway`.

Emacs is enabled on Fedora/GNOME and workstation profiles. `dotfiles_common` deploys the canonical authoring setup, including `~/Org/`, versioned templates, and PDF/HTML/Markdown/DOCX/ODT export support. To turn it on temporarily elsewhere:

```bash
ansible-playbook ansible/site.yml --limit <host> --tags emacs -e emacs_enabled=true
```

## AI coding agents

The shared npm-managed agents are OpenCode, Claude Code, Codex, Gemini CLI, and
GitHub Copilot; IBM Bob is also managed on `deadalus`. Codex Relay is installed
only on `ikaros`. Each agent has its own lifecycle flags in
`ansible/inventory/group_vars/all.yml`, so one agent can be installed,
configured, or removed without affecting the others:

```yaml
ai_agents:
  opencode:
    npm_package: opencode-ai
    install_enabled: true
    deploy_enabled: true
    uninstall_enabled: false
```

Installation uses the npm `latest` state; deployment copies/renders only the
configuration belonging to each enabled agent. Removal deletes only the selected
managed npm package or, for IBM Bob, `/usr/local/bin/bob`; it preserves dotfiles,
instructions, credentials, and user data. Installation and removal are mutually
exclusive per agent: the playbook fails before making changes when both flags are
true for the same agent. Servers set `ai_agents: {}` and therefore manage none.

Run a focused dry run with:

```bash
ansible-playbook ansible/site.yml --limit ikaros --tags ai_agents --check --diff
ansible-playbook ansible/site.yml --limit deadalus --tags ai_agents --check --diff
```

To preview removal, set `install_enabled: false` and `uninstall_enabled: true`
only in the entry for the agent being removed, then run:

```bash
ansible-playbook ansible/site.yml --limit deadalus --tags ai_agents --check --diff
```

## Main roles

| Role | What it does |
| --- | --- |
| `packages_void` | Installs packages on Void. |
| `packages_fedora` | Installs packages on Fedora. |
| `packages_rocky` | Installs packages on Rocky Linux 9. |
| `services_runit` | Manages runit services. |
| `services_systemd` | Manages systemd services. |
| `profile_desktop_common` | Shared Void desktop bootstrap. |
| `profile_desktop_gnome` | Shared Fedora/GNOME desktop dotfiles. |
| `profile_desktop_sway` | Sway / SwayFX Wayland session. |
| `profile_desktop_niri` | Niri Wayland session on Void. |
| `profile_desktop_host` | Host-specific desktop overrides. |
| `profile_personal_workstation` | Stable personal-workstation layer. |
| `profile_workstation_dev_common` | Shared workstation development setup. |
| `profile_workstation_dev_wsl` | WSL development setup. |
| `profile_server` | Server setup. |
| `profile_atlas` | Rocky Linux 9 NAS setup. |
| `profile_backend_phase1` | Temporary rootless Atlas Navidrome and Syncthing services. |
| `wireguard_overlay` | Prometheus/Aegis WireGuard LAN gateway. |
| `profile_aegis` | Fedora IoT always-on LAN node. |
| `dotfiles_common` | Shared user dotfiles. |

## What `site.yml` runs

```text
all except platform_rocky -> dotfiles_common
platform_void -> packages_void + services_runit
platform_void & graphical_desktop -> profile_desktop_common + profile_desktop_sway + profile_desktop_niri + profile_desktop_host
platform_fedora -> packages_fedora + services_systemd
platform_rocky -> packages_rocky + services_systemd
role_aegis -> profile_aegis
wireguard_overlay -> wireguard_overlay (after Aegis profile and platform_rocky)
atlas -> profile_atlas
role_backend_phase1 -> profile_backend_phase1 (after atlas)
rocky_server -> dotfiles_common + profile_server (after platform_rocky)
platform_fedora & role_personal_workstation -> profile_personal_workstation
platform_fedora & desktop_gnome -> profile_desktop_gnome
workstation_dev_fedora -> profile_workstation_dev_common
workstation_dev_wsl -> profile_workstation_dev_wsl (after platform_fedora + workstation_dev_fedora)
```

So, in practice:

- `platform_fedora` configures `ikaros`, `nymph`, and `deadalus`.
- `deadalus` gets the Fedora development layer followed by the WSL layer.
- `rocky_server` configures the Rocky 9 server, `prometheus`.
- `atlas` receives the Rocky platform layer and the NAS profile through SSH.
- `aegis` receives only the immutable Fedora IoT profile through SSH; it does not receive
  mutable Fedora package or common dotfile roles.
- Empty `platform_void` groups do nothing until they get a host.
- The playbook never restarts the display manager during a run.
- `secrets/vault.yml` and then `secrets/vault.local.yml` are loaded only when present.

## Requirements

You will need Python 3, Ansible, `ansible-lint`, `yamllint`, `shellcheck`, and the collections in `ansible/collections/requirements.yml`.

```bash
python3 -m pip install ansible ansible-lint yamllint shellcheck-py
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

Secrets are optional:

- `secrets/vault.yml` can hold shared local vault values.
- `secrets/vault.local.yml` can hold untracked local overrides.
- `secrets/vault.yml.example` is the example template.
- If no vault file exists, the playbook still runs without those optional values.
- `secrets/.vault_pass.gpg` is used when available; `secrets/.vault_pass` is a legacy local fallback. Without either one, Ansible asks for the password interactively.

## Running it

Run the whole playbook:

```bash
ansible-playbook ansible/site.yml
```

Useful checks before applying changes:

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros,nymph --check --diff
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff
ansible-playbook ansible/site.yml --limit atlas --check --diff
ansible-playbook ansible/site.yml --limit aegis --check --diff
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

For focused checks:

```bash
ansible-playbook ansible/site.yml --limit <host> --tags <tag1>,<tag2> --check --diff
ansible-playbook ansible/site.yml --limit <host> --start-at-task "<task name>" --check --diff
ansible-lint ansible/roles/<role>
yamllint ansible/path/to/file.yml
podman-compose -f /opt/docker/server/docker-compose.yml config
ansible-playbook ansible/site.yml --limit atlas --tags storage,sharing,containers --check --diff
```

## Tags

Use Ansible as the source of truth for the current tag list:

```bash
ansible-playbook ansible/site.yml --list-tags
```

| Tag | Main scope |
| --- | --- |
| `always` | Common pre-tasks, including optional vault loading. |
| `ai_agents` | AI coding-agent install, configuration deployment, and managed-binary removal. |
| `atlas` | Atlas NAS account, storage, sharing, and container configuration. |
| `backend_phase1` | Rootless Atlas Navidrome and Syncthing Quadlets. |
| `containers` | Rootful Atlas Quadlets. |
| `dotfiles` | User configuration across all profiles. |
| `dotfiles:common` | Shared dotfiles. |
| `dotfiles:desktop` | Void and Fedora/GNOME desktop dotfiles. |
| `dotfiles:host` | Host-specific Void desktop overrides. |
| `dotfiles:server` | Server dotfiles. |
| `dotfiles:workstation` | Personal workstation and WSL dotfiles. |
| `emacs` | Shared Emacs setup and authoring dependencies. |
| `gnome` | Fedora/GNOME desktop configuration. |
| `immich` | Atlas Immich account and Quadlets. |
| `npm` | Global npm packages. |
| `packages` | Package installation and updates. |
| `podman` | Podman Compose and rootless Quadlet integration. |
| `services` | runit and systemd services. |
| `sharing` | Atlas NFSv4 and SMB3 configuration. |
| `storage` | Atlas child ZFS datasets. |
| `tmux` | tmux configuration and plugins. |
| `wireguard` | Prometheus/Aegis WireGuard LAN gateway. |
| `wsl` | WSL bootstrap and configuration. |

## Bootstrapping a new machine

```bash
git clone <repo>
cd <repo-dir>
ansible-galaxy collection install -r ansible/collections/requirements.yml
ansible-playbook ansible/site.yml
```

For a future Void desktop host:

1. Add it to `platform_void`.
2. Add it to `graphical_desktop`.
3. Use Sway, or add it to `desktop_niri` for Niri.
4. Put hardware-specific details in `host_vars/<host>.yml`.

The legacy `void` and `desktop` groups remain compatibility parents, so hosts in `platform_void` and `graphical_desktop` still receive the existing Void and desktop variables.
