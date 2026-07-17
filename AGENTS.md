# AGENTS.md

Ansible-driven personal infrastructure repo for Fedora and Void desktops, Linux Mint and FreeBSD transition targets, Linux workstations, WSL, and an Ubuntu server.

## Source Of Truth
- Main orchestration: `ansible/site.yml`
- Inventory and layering inputs: `ansible/inventory/hosts.yml`, `ansible/inventory/group_vars/*.yml`, `ansible/inventory/host_vars/*.yml`
- Dotfiles live under `dotfiles/`
- AI agent instructions (bootstrap, rules, knowledge) are centralized in `dotfiles/common/.config/ai/` and shared between OpenCode, Codex, and Gemini CLI.
- OpenCode loads its entrypoint configuration from `dotfiles/common/.config/opencode/opencode.json`.
- Codex config is rendered from `dotfiles/common/.codex/config.toml.j2` so `model_instructions_file` points to the deployed `~/.config/ai/bootstrap.md`.

## Topology
- Current personal desktop: `ikaros = platform_mint + role_personal_workstation + desktop_cinnamon`
- Current laptop: `nymph = platform_fedora + graphical_desktop + desktop_gnome`
- Void desktop profile is also the base for other future/reference hosts via `platform_void + graphical_desktop`
- Native Linux workstation: `deadalus-fedora`
- WSL dev: `deadalus-wsl`
- Ubuntu server: `prometheus`
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
  - Mint desktop work: `ansible-playbook ansible/site.yml --limit ikaros --check --diff`
  - Fedora laptop work: `ansible-playbook ansible/site.yml --limit nymph --check --diff`
  - Fedora workstation: `ansible-playbook ansible/site.yml --limit deadalus-fedora --check --diff`
  - WSL dev: `ansible-playbook ansible/site.yml --limit deadalus-wsl --check --diff`
  - Server: `ansible-playbook ansible/site.yml --limit prometheus --check --diff`
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
- `desktop_profile` names independently selectable desktop groups such as `desktop_gnome`, `desktop_hyprland`, `desktop_sway`, `desktop_niri`, and `desktop_cinnamon`. Keep platform-specific session bootstrap in platform-specific roles.
- `desktop_environment` selects the mutually exclusive `minimal` (default), `gnome`, `xfce`, or `kde` desktop mode. `profile_desktop_common` owns shared Void bootstrap; the minimal mode uses `profile_desktop_sway`, `profile_desktop_hyprland`, and `profile_desktop_niri`, `profile_desktop_xfce` owns the reproducible XFCE setup, `profile_desktop_kde` owns KDE-specific defaults and cleanup, and `profile_desktop_gnome` copies shared desktop dotfiles for Fedora/GNOME without managing GNOME settings. `desktop_sessions_enabled` and `desktop_default_session` apply only to the minimal mode.
- Emacs packages and `.emacs.d` deploy are disabled by default via `emacs_enabled: false`; keep the dotfiles in the repo for reversible opt-in only.
- NTFS filesystem support is provided by `ntfs-3g` in `ansible/inventory/group_vars/void.yml`.
- Void user services are managed by `turnstile` and live under `dotfiles/desktop/.config/service/`.
- `ssh-agent` keeps the stable socket `~/.local/state/ssh-agent/socket`.
- Critical session entrypoints:
  - `dotfiles/desktop/.config/sway/config` plus `host.conf` and `session-env` deployed via `host_sway_dotfiles` (sway / Wayland)
  - `dotfiles/desktop/.config/hypr/hyprland.conf` plus `host.conf` and `session-env` deployed via `host_hyprland_dotfiles` (Hyprland / Wayland)
  - `dotfiles/desktop/.config/niri/config.kdl` and `session-env` deployed via `desktop_niri_dotfiles` (Niri / Wayland)
- Void Niri lives in `profile_desktop_niri`, gated on `'niri' in desktop_sessions_enabled`; it installs the `emptty` `niri.desktop` session, the `/usr/local/bin/start-niri` launcher, and the xdg-desktop-portal config, mirroring `profile_desktop_sway`.
- Fedora GNOME (`desktop_gnome`) assumes GNOME comes from the Fedora Workstation base install; Ansible only deploys shared desktop dotfiles and git/GPG config for `nymph`, not GNOME settings.
- FreeBSD Niri (dormant; `platform_freebsd` currently has no hosts) must keep FreeBSD-specific package, rc, DBus, seat, portal, and launcher behavior in `profile_desktop_niri_freebsd` or FreeBSD platform vars.
- Do not switch or restart a display manager during a playbook run from an active graphical session. Changing among `emptty`, LightDM, and SDDM requires an explicit run from another TTY/SSH session with `desktop_allow_display_manager_switch=true`. Apply managed XFCE XML while logged out of XFCE so `xfconfd` cannot overwrite it from its in-memory state.
- `nymph` is the Fedora/GNOME laptop target; keep GNOME settings unmanaged for now and add host-specific tuning only after real use.

## Void Package And Dotfile Bucket Rules
`platform_void` is the reusable Void platform selection. The legacy `void` group remains a compatibility parent so existing `group_vars/void.yml` and `when: "'void' in group_names"` checks keep working during the transition.
The Void desktop package lists in `ansible/inventory/group_vars/void.yml` are kept disjoint by role:
- `void_packages_base` — system runtime only (init/services, kernel, audio core, networking, filesystem, firewall, hardware daemons, runit logging).
- `desktop_common_packages` — GUI infrastructure shared by all desktop modes.
- `desktop_minimal_packages` / `desktop_xfce_packages` / `desktop_kde_packages` — mutually exclusive applications, integration components, and display managers. Packages required by more than one exclusive mode may be repeated; cleanup subtracts the selected mode before removing inactive packages.
- `desktop_sway_packages` / `desktop_hyprland_packages` — binaries specific to each session. Cross-WM packages used by both (such as `dunst`, `rofi`, and `foot`) are intentionally duplicated in the two lists.
`profile_packages` in the same file is cross-distro and is overridden by `group_vars/server.yml` and the workstation group vars; do not move desktop-specific Void entries through it.
The dotfile vars follow the same split: `desktop_common_dotfiles` carries mode-independent content, `desktop_minimal_dotfiles` carries Thunar, Udiskie, and minimal MIME defaults, and `desktop_xfce_dotfiles` carries XFCE state. KDE uses its own MIME defaults. `desktop_void_dotfiles` remains reserved for files that need the Void runtime.

## Workstation Notes
- Native Linux workstation hosts can combine `workstation_host_linux` with an OS-specific dev group.
- `deadalus-fedora` keeps GNOME managed settings in `ansible/inventory/host_vars/deadalus-fedora.yml`.

## Coding Agent Notes
- Shared agent packages live in `ai_agents_npm_packages` in `ansible/inventory/group_vars/all.yml`.
- Shared agent dotfiles live in `ai_agents_dotfiles`; rendered configs live in `ai_agents_templates`.
- Desktop, native workstation, and WSL profiles consume the shared agent package list; do not duplicate package entries in profile-specific vars.
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
