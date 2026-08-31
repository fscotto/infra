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
│   ├── ubuntu/
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

The repo currently covers Fedora/GNOME desktops, one Fedora WSL workstation, an Ubuntu server, and
a Rocky Linux 9 NAS. Configuration is layered instead of being tied to host names:

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
| `prometheus` | Ubuntu | Server | — |
| `atlas` | Rocky 9 | NAS | — |

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

That gives it Fedora packages through DNF, Docker from the official repository, shared workstation dotfiles and templates, tmux helpers, and WSL systemd configuration. Windows applications are installed manually; the WSL profile does not manage Python remoting components for them.

### WSL workflow

1. Start Fedora WSL once and finish creating the Linux user.
2. Install Ansible inside Fedora WSL.
3. Run the playbook from that distribution with `--limit deadalus`.
4. Use Windows-side VS Code with Remote WSL, Remote SSH, and Dev Containers if wanted.

## Server

`prometheus` is the Ubuntu LTS server. It has no graphical environment and gets server-specific dotfiles and templates.

The server profile installs Ubuntu packages, Docker from the official repository, declared systemd services, UFW rules, and the server Compose stack. Syncthing ports `22000/tcp`, `22000/udp`, and `21027/udp` are opened; the Syncthing GUI is not directly opened in UFW.

Server identity comes from `server_username`, `server_user_group`, and `server_user_home` in `ansible/inventory/group_vars/server.yml`. `server_username` defaults to `username`, but it can be overridden, for example:

```bash
ansible-playbook ansible/site.yml --limit prometheus -e server_username=myuser
ansible-playbook ansible/site.yml --limit prometheus \
  -e server_username=myuser -e server_user_group=mygroup \
  -e server_user_home=/srv/myuser
```

## NAS

`atlas` is a Rocky Linux 9 NAS reached through SSH. Its pool already exists: the profile only
manages child datasets and must never create, partition, destroy, roll back, or otherwise alter the
pool itself. Linux clients use NFSv4 and Windows/WSL clients use SMB; both are restricted to the
configured LAN.

For the first run, replace the Atlas placeholders and provide
`vault_atlas_authorized_ssh_keys`, `vault_atlas_admin_password_hash`, and
`vault_atlas_samba_password`. Bootstrap the host through its existing administrator:

```bash
ansible-playbook ansible/site.yml --limit atlas \
  -e atlas_connection_username=<existing-admin>
```

`vault_atlas_admin_password_hash` must be an `/etc/shadow`-compatible hash, not a clear-text
Cockpit password. Subsequent runs use `atlas_admin_username`. Enable
`atlas_manage_storage` only after checking the existing pool and mountpoints; enable
`atlas_manage_firewall` only after checking the LAN subnet and active firewalld zone.

Snapshot retention, Syncthing topology, VPN access, Prometheus pulls, encrypted Borg backups to a
Hetzner Storage Box, USB backup, monitoring, and disaster-recovery tests remain follow-up work. The
detailed operational backlog is kept in `AGENTS.md`.

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
| `packages_freebsd` | Installs packages on FreeBSD with pkg. |
| `packages_ubuntu` | Installs packages on Ubuntu. |
| `packages_fedora` | Installs packages on Fedora. |
| `packages_rocky` | Installs packages on Rocky Linux 9. |
| `services_runit` | Manages runit services. |
| `services_systemd` | Manages systemd services. |
| `services_freebsd` | Manages declared FreeBSD rc services. |
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
| `dotfiles_common` | Shared user dotfiles. |

## What `site.yml` runs

```text
all -> dotfiles_common
platform_void -> packages_void + services_runit
platform_void & graphical_desktop -> profile_desktop_common + profile_desktop_sway + profile_desktop_niri + profile_desktop_host
platform_freebsd -> packages_freebsd + services_freebsd
platform_fedora -> packages_fedora + services_systemd
platform_rocky -> packages_rocky + services_systemd
atlas -> profile_atlas
platform_fedora & role_personal_workstation -> profile_personal_workstation
platform_fedora & desktop_gnome -> profile_desktop_gnome
workstation_dev_fedora -> profile_workstation_dev_common
workstation_dev_wsl -> profile_workstation_dev_wsl (after platform_fedora + workstation_dev_fedora)
ubuntu_server -> packages_ubuntu + services_systemd + profile_server
```

So, in practice:

- `platform_fedora` configures `ikaros`, `nymph`, and `deadalus`.
- `deadalus` gets the Fedora development layer followed by the WSL layer.
- `ubuntu_server` configures `prometheus`.
- `atlas` receives the Rocky platform layer and the NAS profile through SSH.
- Empty `platform_void` and `platform_freebsd` groups do nothing until they get a host.
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
docker compose -f /opt/docker/server/docker-compose.yml config
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
| `dotfiles` | User configuration across all profiles. |
| `dotfiles:common` | Shared dotfiles. |
| `dotfiles:desktop` | Void and Fedora/GNOME desktop dotfiles. |
| `dotfiles:host` | Host-specific Void desktop overrides. |
| `dotfiles:server` | Server dotfiles. |
| `dotfiles:workstation` | Personal workstation and WSL dotfiles. |
| `emacs` | Shared Emacs setup and authoring dependencies. |
| `gnome` | Fedora/GNOME desktop configuration. |
| `npm` | Global npm packages. |
| `packages` | Package installation and updates. |
| `services` | runit and systemd services. |
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
