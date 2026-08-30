# AGENTS.md

Ansible-driven personal infrastructure repo for Fedora and Void desktops, FreeBSD transition targets, WSL, and an Ubuntu server.

## Source Of Truth
- Main orchestration: `ansible/site.yml`
- Inventory and layering inputs: `ansible/inventory/hosts.yml`, `ansible/inventory/group_vars/*.yml`, `ansible/inventory/host_vars/*.yml`
- Dotfiles live under `dotfiles/`
- AI agent instructions (bootstrap, rules, knowledge) are centralized in `dotfiles/common/.config/ai/` and shared between OpenCode, Codex, and Gemini CLI.
- OpenCode loads its entrypoint configuration from `dotfiles/common/.config/opencode/opencode.json`.
- Codex config is rendered from `dotfiles/common/.codex/config.toml.j2` so `model_instructions_file` points to the deployed `~/.config/ai/bootstrap.md`.

## Topology
- Current personal desktop: `ikaros = platform_fedora + role_personal_workstation + graphical_desktop + desktop_gnome`
- Current laptop: `nymph = platform_fedora + graphical_desktop + desktop_gnome`
- Void desktop profile is also the base for other future/reference hosts via `platform_void + graphical_desktop`
- Workstation: `deadalus` is Windows + Fedora WSL.
- Ubuntu server: `prometheus`
- NAS: `atlas` (Rocky Linux 9, reached through SSH)
- Hosts intentionally belong to multiple groups; trust `ansible/site.yml` over hostname assumptions.
- Inventory axes are independent: `platform_*`, `role_*`, and `desktop_*`. Legacy `void` and `desktop` remain compatibility parents.

## Working Rules
- Preserve layering `all -> platform -> role -> desktop -> host`.
- Keep `ansible/site.yml` small; orchestration belongs there, implementation belongs in roles.
- Prefer minimal, targeted edits. Preserve idempotency and existing ordering.
- All hosts use `ansible_connection: local`.
- Treat `secrets/` as sensitive. Never print secret values.
- Tmux plugins are bootstrapped by TPM on the host; the repo only keeps tmux config and custom helper scripts.
- Read the relevant role tasks, templates, vars, and deployed dotfiles before editing.

## Validation
- Default minimum:
  - `ansible-playbook ansible/site.yml --syntax-check`
- Repo-wide checks:
  - `ansible-lint ansible/site.yml`
  - `ansible-lint ansible/roles`
  - `yamllint ansible/`
- Host-focused dry runs:
  - Fedora desktop work: `ansible-playbook ansible/site.yml --limit ikaros --check --diff`
  - Fedora laptop work: `ansible-playbook ansible/site.yml --limit nymph --check --diff`
  - WSL workstation dev: `ansible-playbook ansible/site.yml --limit deadalus --check --diff`
  - Server: `ansible-playbook ansible/site.yml --limit prometheus --check --diff`
  - Atlas NAS: `ansible-playbook ansible/site.yml --limit atlas --check --diff`
- Focused checks:
  - Emacs is disabled by default; temporary Emacs check: `ansible-playbook ansible/site.yml --limit <host> --tags emacs --check --diff -e emacs_enabled=true`
  - Mail bootstrap: `sh -n scripts/bootstrap_mail.sh` and `shellcheck scripts/bootstrap_mail.sh`
  - Server compose render: `docker compose -f /opt/docker/server/docker-compose.yml config`

## Conventions
- Use FQCN Ansible modules.
- Prefer declarative modules over `command`/`shell`; when `shell` is required, make idempotency and failure behavior explicit.
- Start YAML files with `---`, use 2-space indentation, and keep file modes quoted like `"0644"`.
- Keep booleans as booleans and structured vars as YAML lists/maps.
- Put host-specific overrides in `host_vars`, not shared `group_vars`.
- Use `no_log: true` for secret-bearing task inputs or outputs.

## Desktop Notes
- `desktop_profile` names independently selectable desktop groups such as `desktop_gnome`, `desktop_sway`, and `desktop_niri`. Keep platform-specific session bootstrap in platform-specific roles.
- `desktop_environment` is fixed to `minimal` for Void desktops. `profile_desktop_common` owns shared Void bootstrap; `profile_desktop_sway` and `profile_desktop_niri` manage the enabled sessions, while `profile_desktop_gnome` copies shared desktop dotfiles for Fedora/GNOME without managing GNOME settings. `desktop_sessions_enabled` and `desktop_default_session` apply to the minimal mode.
- Emacs has one authoring-oriented `.emacs.d`, deployed by `dotfiles_common` when `emacs_enabled` is true. Fedora/GNOME desktops and workstation profiles enable it; keep platform dependencies in package group vars rather than branching in Emacs Lisp.
- NTFS filesystem support is provided by `ntfs-3g` in `ansible/inventory/group_vars/void.yml`.
- Void user services are managed by `turnstile` and live under `dotfiles/desktop/.config/service/`.
- `ssh-agent` keeps the stable socket `~/.local/state/ssh-agent/socket`.
- Critical session entrypoints:
  - `dotfiles/desktop/.config/sway/config` plus `host.conf` and `session-env` deployed via `host_sway_dotfiles` (sway / Wayland)
  - `dotfiles/desktop/.config/niri/config.kdl` and `session-env` deployed via `desktop_niri_dotfiles` (Niri / Wayland)
- Void Niri lives in `profile_desktop_niri`, gated on `'niri' in desktop_sessions_enabled`; it installs the `emptty` `niri.desktop` session, the `/usr/local/bin/start-niri` launcher, and the xdg-desktop-portal config, mirroring `profile_desktop_sway`.
- Fedora GNOME (`desktop_gnome`) assumes GNOME comes from the Fedora Workstation base install; Ansible deploys shared desktop dotfiles and git/GPG config for `ikaros` and `nymph`, not GNOME settings.
- Do not switch or restart the display manager during a playbook run from an active graphical session.
- `nymph` is the Fedora/GNOME laptop target; keep GNOME settings unmanaged for now and add host-specific tuning only after real use.

## Void Package And Dotfile Bucket Rules
`platform_void` is the reusable Void platform selection. The legacy `void` group remains a compatibility parent so existing `group_vars/void.yml` and `when: "'void' in group_names"` checks keep working during the transition.
The Void desktop package lists in `ansible/inventory/group_vars/void.yml` are kept disjoint by role:
- `void_packages_base` — system runtime only (init/services, kernel, audio core, networking, filesystem, firewall, hardware daemons, runit logging).
- `desktop_common_packages` — GUI infrastructure shared by the minimal desktop mode.
- `desktop_minimal_packages` — applications, integration components, and the `emptty` display manager.
- `desktop_sway_packages` — binaries specific to the Sway session.
`profile_packages` in the same file is cross-distro and is overridden by `group_vars/server.yml` and the workstation group vars; do not move desktop-specific Void entries through it.
The dotfile vars follow the same split: `desktop_common_dotfiles` carries mode-independent content and `desktop_minimal_dotfiles` carries Thunar, Udiskie, and MIME defaults. `desktop_void_dotfiles` remains reserved for files that need the Void runtime.

## Workstation Notes
- `deadalus` is modeled as Windows + Fedora WSL and is the sole workstation target.
- Fedora WSL belongs to `platform_fedora`, `workstation_dev_fedora`, and the shared WSL layer. It must not receive Flatpak or Snap runtimes.
- Windows applications are installed manually and are not managed from the WSL profile.

## Atlas NAS Notes
- `atlas` is a remote Rocky Linux 9 NAS. Keep its connection, LAN, pool and mountpoint values in
  `host_vars/atlas.yml`. Bootstrap it once with `-e atlas_connection_username=<existing-admin>`;
  subsequent runs use the dedicated Atlas account.
- The pool is pre-existing: never add pool creation, disk partitioning, RAIDZ creation, rollback,
  or destruction to the Atlas profile.
- `atlas_manage_storage` and `atlas_manage_firewall` remain false until their placeholders are
  replaced; only then may the profile manage datasets, shares and LAN-restricted firewall rules.
- Atlas requires `vault_atlas_authorized_ssh_keys`, `vault_atlas_admin_password_hash` for Cockpit
  and, when storage is enabled, `vault_atlas_samba_password`. Never print these values.
- Atlas uses NFSv4 for Linux and SMB for Windows/WSL, restricted to the configured LAN. Snapshot,
  Borg/Hetzner offsite backup, Prometheus pull and USB backup automation are intentionally deferred.

## Atlas NAS TODO
- Replace every Atlas `CHANGEME` value, provide the required Vault variables and validate the first
  remote bootstrap on the real Rocky Linux 9 host. Enable `atlas_manage_storage` first and
  `atlas_manage_firewall` only after confirming the pool, mountpoints, LAN subnet and firewalld zone.
- Validate the complete baseline on the target: OpenZFS kmod loading, existing pool import, dataset
  mounts, SSH reconnect, Cockpit and all selected 45Drives plugins, NFSv4, SMB and Syncthing.
- Finalize dataset properties and the shared UID/GID, group and POSIX ACL model; test the same files
  through both NFS and SMB before considering multiprotocol access complete.
- Add Ansible-managed ZFS snapshot retention and scrub timers. Use Cockpit Scheduler for visibility
  or manual operations, not as the only source of configuration, and never automate snapshot rollback.
- Manage the Syncthing star topology, device IDs, folders, folder modes, ignore rules and protected GUI
  or API access for the selected clients.
- Add Tailscale or WireGuard and corresponding LAN/VPN-only firewalld rules before enabling remote
  services; never expose SSH, Cockpit, NFS, SMB or Syncthing through public port forwarding.
- Add the least-privilege Prometheus backup flow: remote dump generation, dedicated SSH identity,
  pinned host key, atomic pull, verification, retention and an Atlas systemd service/timer.
- Add the encrypted offsite backup with Borg to a Hetzner Storage Box: use a dedicated SSH identity,
  pin the host key, keep Borg repository credentials and encryption material in Vault, use
  snapshot-consistent sources, and manage retries, logging, pruning, repository checks and restores.
- Add the UUID-bound offline USB backup with versioned rsync, locking, capacity checks, verification,
  safe unmounting and a tested restore procedure; never trigger it for an arbitrary USB disk.
- Add monitoring and alerting for pool health, scrub/resilver, SMART data, temperatures, free space and
  failed backup timers, plus a controlled Rocky kernel/OpenZFS update and reboot procedure.
- Document and test disaster recovery: rebuild Atlas with Ansible, import the existing pool, restore
  from snapshot/USB/Hetzner, preserve Vault and Borg recovery material offline, and define RPO/RTO.
- Optionally design iCloud photo ingestion as a separate workflow after the storage and backup layers
  are validated; do not make it a dependency of the Atlas baseline.

## Coding Agent Notes
- Shared agent packages live in `ai_agents_npm_packages` in `ansible/inventory/group_vars/all.yml`.
- Shared agent dotfiles live in `ai_agents_dotfiles`; rendered configs live in `ai_agents_templates`.
- Desktop and WSL profiles consume the shared agent package list; do not duplicate package entries in profile-specific vars.
- `dotfiles_common` copies common dotfiles plus `ai_agents_dotfiles`, then renders `ai_agents_templates`.
- Keep `.config/ai/` as the common instruction source; update agent-specific entrypoints to reference it rather than duplicating instruction text.

## Tooling Notes
- Install local tooling with:
  - `python3 -m pip install ansible ansible-lint yamllint shellcheck-py`
  - `ansible-galaxy collection install -r ansible/collections/requirements.yml`
- Required collections currently include `ansible.posix` and `community.general`.
- `.yamllint` treats `line-length` as a warning at 120 chars and disables `document-start` and `comments-indentation`.

## When Updating Docs
- Keep `README.md` and `AGENTS.md` aligned when workflows materially change.
- If you add a new operational area, also add the narrowest validation command for it.
- Call out checks you could not run and any follow-up verification needed.
