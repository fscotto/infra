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
services, and firewalld. The manually activated `podman-compose-server` unit now contains Nginx Proxy
Manager, Gitea, and the existing Navidrome PostgreSQL database. Navidrome itself runs as a rootless
user Quadlet and reads the Atlas music dataset from the system `rclone-music.service` mount at
`/mnt/music_atlas`. The Rocky server excludes Syncthing.
Rocky bind mounts use private SELinux relabeling where supported; the read-only FUSE music mount is
passed to Navidrome without relabeling.

The Atlas music path is gated by `server_atlas_music_enabled`. Before enabling it, replace the
WireGuard address and pinned SSH host-key placeholders in `host_vars/prometheus.yml`, and provide
`vault_prometheus_atlas_sftp_private_key` through encrypted Vault or untracked local vars. The SFTP
key's public half must already be present in Atlas' managed authorized keys. Rclone mounts the exact
remote path `/pool/media/music` read-only and uses a `15G` full VFS cache; the rootless user manager is
kept alive through systemd lingering.
Configure the Prometheus NPM proxy host for Navidrome as `host.containers.internal:4533`; the
Navidrome port is not opened through firewalld.
Before the first enablement, stop the legacy rootful `navidrome` container. The role refuses to start
the rootless replacement while that container is running and never removes the old container or data.

Firewalld enables SSH, Cockpit (`9090/tcp`), HTTP and HTTPS. Nginx Proxy Manager publishes only
`80/tcp` and `443/tcp`; its administration interface is bound to `127.0.0.1:81` and can be reached
from Ikaros or Nymph with the `npm-tunnel` Bash alias. Nextcloud remains disabled and the profile
does not provision any `/srv/nextcloud` directories.

Server identity comes from `server_username`, `server_user_group`, and `server_user_home` in `ansible/inventory/group_vars/server.yml`. `server_username` defaults to `username`, but it can be overridden, for example:

```bash
ansible-playbook ansible/site.yml --limit prometheus -e server_username=myuser
ansible-playbook ansible/site.yml --limit prometheus \
  -e server_username=myuser -e server_user_group=mygroup \
  -e server_user_home=/srv/myuser
```

The target must already provide `server_username` with local sudo access.

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
dry-run by default and requires an explicit source-stack stop before it can copy PostgreSQL data:

```bash
sudo ./scripts/migrate_prometheus_data.sh \
  --destination rocky@179.237.102.172 \
  --identity /root/.ssh/id_ed25519

sudo ./scripts/migrate_prometheus_data.sh \
  --destination rocky@179.237.102.172 \
  --identity /root/.ssh/id_ed25519 \
  --quiesce-source --execute
```

The script copies Navidrome, music, Nginx Proxy Manager, PostgreSQL and Gitea data. It does not
delete data, move Syncthing, copy `/home/git/.ssh`, start containers, update DNS, or perform a
cutover. The destination SSH host key must already be trusted and the destination account needs
passwordless sudo for `rsync`. It preserves ACLs but not extended attributes, so source SELinux labels
are not transferred; the Rocky Compose bind mounts apply their own `:Z` labels when containers start.

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
firewalld rules, SSH key-only access for `pi`, and `wake-ikaros`. Set the host-local
`aegis_lan_subnet` and `aegis_adguard_web_port` values before applying it. The playbook permits
AdGuard Home HTTP on port `80`; the initial wizard port `3000` is intentionally unmanaged and must be
opened and closed manually during initial setup. The profile disables the local systemd-resolved DNS
stub and points `/etc/resolv.conf` to its full resolver data, freeing port 53
for AdGuard while retaining DNS learned from the router. Define
`vault_aegis_icloudpd_apple_id` in Vault before applying it. iCloudPD still requires interactive MFA
initialization after its first deployment.

Validate the profile before deployment:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit aegis --check --diff --ask-become-pass
```

## NAS

`atlas` is a Rocky Linux 9 NAS reached through SSH. Its pool already exists: the profile only
manages child datasets and must never create, partition, destroy, roll back, or otherwise alter the
pool itself. Linux clients use NFSv4 and Windows/WSL clients use SMB; both are restricted to the
configured LAN.

For the first run, replace the Atlas host, pool, mount-root, LAN, and Aegis-IP
placeholders and provide `vault_atlas_authorized_ssh_keys`, `vault_atlas_admin_password_hash`,
`vault_atlas_samba_password`, and `vault_atlas_immich_db_password`. Bootstrap the host through its
existing administrator:

```bash
ansible-playbook ansible/site.yml --limit atlas \
  -e atlas_connection_username=<existing-admin>
```

`vault_atlas_admin_password_hash` must be an `/etc/shadow`-compatible hash, not a clear-text
Cockpit password. Subsequent runs use `atlas_admin_username`. Enable `atlas_manage_storage` only after
checking the existing pool and mountpoints; enable `atlas_manage_firewall` only after checking the LAN
subnet and active firewalld zone. Enable `atlas_manage_media_stack` last, after validating `/dev/dri`,
the container paths and the Immich database secret.

With storage management enabled, Atlas creates `archive` (`zstd`), `media/music` (`lz4`),
`media/icloud_photos` (`lz4`), and `backups/services` (`lz4`, `refreservation=500G`) beneath the
pre-existing pool. The existing Work, Syncthing, and Prometheus-backup datasets remain managed and
separate. SMB3 exposes `Archive` only to the configured Vault-backed Samba accounts and admits the
configured LAN without host-specific exclusions. NFSv4 exports only
`media/icloud_photos` to the configured Aegis IP, using `all_squash` with anonymous UID/GID `1100`.

The `immich` system account is fixed to UID/GID `1100`, has no login shell or `wheel` membership, and
receives `video` and `render` access. The rootful Immich Server, ML, Redis-compatible cache, PostgreSQL,
and NPM Quadlets share one Podman network. Immich runs as `1100:1100`; Server and ML receive `/dev/dri`,
and iCloud Photos is mounted read-only as an external library. NPM publishes ports `80` and `443`; its
administration interface remains restricted to `127.0.0.1:81` for SSH-tunnel access.

Snapshot retention, Syncthing topology, WireGuard/firewall validation, Prometheus backup pulls,
encrypted Borg backups to a Hetzner Storage Box, USB backup, monitoring, and disaster-recovery tests
remain follow-up work. The detailed operational backlog is kept in `AGENTS.md`.

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
GitHub Copilot; IBM Bob is also managed on `deadalus`. Each agent has its own
lifecycle flags in `ansible/inventory/group_vars/all.yml`, so one agent can be
installed, configured, or removed without affecting the others:

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
atlas -> profile_atlas
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
ansible-playbook ansible/site.yml --limit prometheus --tags rclone,navidrome --check --diff
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
| `navidrome` | Prometheus rclone mount and rootless Navidrome Quadlet. |
| `npm` | Global npm packages. |
| `packages` | Package installation and updates. |
| `podman` | Podman Compose and rootless Quadlet integration. |
| `rclone` | Prometheus Atlas music mount. |
| `services` | runit and systemd services. |
| `sharing` | Atlas NFSv4 and SMB3 configuration. |
| `storage` | Atlas child ZFS datasets. |
| `tmux` | tmux configuration and plugins. |
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
