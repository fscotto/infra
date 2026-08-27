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
- Workstation: `deadalus` is Windows + WSL; Ansible targets are `deadalus-wsl` (Ubuntu) and `deadalus-fedora-wsl` (Fedora)
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
  - Fedora desktop work: `ansible-playbook ansible/site.yml --limit ikaros --check --diff`
  - Fedora laptop work: `ansible-playbook ansible/site.yml --limit nymph --check --diff`
  - Ubuntu WSL dev: `ansible-playbook ansible/site.yml --limit deadalus-wsl --check --diff`
  - Fedora WSL dev: `ansible-playbook ansible/site.yml --limit deadalus-fedora-wsl --check --diff`
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
- `deadalus` is modeled as Windows + WSL; keep Linux dev automation on `deadalus-wsl` (Ubuntu) and `deadalus-fedora-wsl` (Fedora).
- Fedora WSL belongs to `platform_fedora`, `workstation_dev_fedora`, and the shared WSL layer. It must not receive Flatpak or Snap runtimes.
- Native Linux workstation groups remain available for future hosts but have no current host in the main inventory.

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
