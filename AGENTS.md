# AGENTS.md

Ansible-driven personal infrastructure repo for Void desktops, Linux workstations, Windows+WSL, and an Ubuntu server.

## Source Of Truth
- Main orchestration: `ansible/site.yml`
- Inventory and layering inputs: `ansible/inventory/hosts.yml`, `ansible/inventory/group_vars/*.yml`, `ansible/inventory/host_vars/*.yml`
- Dotfiles live under `dotfiles/`
- AI agent instructions (bootstrap, rules, knowledge) are centralized in `dotfiles/common/.config/ai/` and shared between OpenCode, Codex, and Gemini CLI.
- OpenCode loads its entrypoint configuration from `dotfiles/common/.config/opencode/opencode.json`.
- Codex config is rendered from `dotfiles/common/.codex/config.toml.j2` so `model_instructions_file` points to the deployed `~/.config/ai/bootstrap.md`.

## Topology
- Void desktops: `ikaros`, `nymph`
- Native Linux workstations: `deadalus-ubuntu`, `deadalus-fedora`
- Windows host + WSL dev: `deadalus-win`, `deadalus-wsl`
- Ubuntu server: `prometheus`
- Hosts intentionally belong to multiple groups; trust `ansible/site.yml` over hostname assumptions.

## Working Rules
- Preserve layering `all -> OS -> profile -> host`.
- Keep `ansible/site.yml` small; orchestration belongs there, implementation belongs in roles.
- Prefer minimal, targeted edits. Preserve idempotency and existing ordering.
- Most hosts use `ansible_connection: local`; Windows host is the exception.
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
  - Void desktop work: `ansible-playbook ansible/site.yml --limit ikaros --check --diff` or `--limit nymph --check --diff`
  - Ubuntu workstation: `ansible-playbook ansible/site.yml --limit deadalus-ubuntu --check --diff`
  - Fedora workstation: `ansible-playbook ansible/site.yml --limit deadalus-fedora --check --diff`
  - WSL dev: `ansible-playbook ansible/site.yml --limit deadalus-wsl --check --diff`
  - Server: `ansible-playbook ansible/site.yml --limit prometheus --check --diff`
- Focused checks:
  - Emacs dotfiles only: `ansible-playbook ansible/site.yml --limit ikaros --tags emacs --check --diff` or `--limit nymph --tags emacs --check --diff`
  - Mail bootstrap: `sh -n scripts/bootstrap_mail.sh` and `shellcheck scripts/bootstrap_mail.sh`
  - Windows bootstrap parse: `pwsh -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('scripts/bootstrap_windows_workstation.ps1', [ref]$null, [ref]$null)"`
  - Server compose render: `docker compose -f /opt/docker/server/docker-compose.yml config`

## Conventions
- Use FQCN Ansible modules.
- Prefer declarative modules over `command`/`shell`; when `shell` is required, make idempotency and failure behavior explicit.
- Start YAML files with `---`, use 2-space indentation, and keep file modes quoted like `"0644"`.
- Keep booleans as booleans and structured vars as YAML lists/maps.
- Put host-specific overrides in `host_vars`, not shared `group_vars`.
- Use `no_log: true` for secret-bearing task inputs or outputs.

## Desktop Notes
- `profile_desktop_common` owns the shared desktop bootstrap; `profile_desktop_i3` (X11) and `profile_desktop_sway` (Wayland/SwayFX) install their respective session in parallel and are both wired into the `void` play in `ansible/site.yml`. `desktop_sessions_enabled` and `desktop_default_session` in host vars decide which sessions are exposed in `emptty` and which is preselected.
- `.emacs.d` is deployed by a dedicated `profile_desktop_common` task tagged `emacs`.
- NTFS filesystem support is provided by `ntfs-3g` in `ansible/inventory/group_vars/void.yml`.
- Void user services are managed by `turnstile` and live under `dotfiles/desktop/.config/service/`.
- `ssh-agent` keeps the stable socket `~/.local/state/ssh-agent/socket`.
- Critical session entrypoints:
  - `dotfiles/desktop/.xinitrc` (i3 / X11)
  - `dotfiles/desktop/.config/sway/config` plus `host.conf` and `session-env` deployed via `host_sway_dotfiles` (sway / Wayland)
- Do not auto-restart `emptty` during playbook runs on active Void desktop hosts; restart it manually from another TTY/SSH session if needed.
- `nymph` is a Void laptop with NVIDIA Optimus, running both i3 (X11) and sway (Wayland); host-specific tasks in `profile_desktop_host/tasks/nymph.yml` handle GRUB NVIDIA cmdline params, `prime-run` wrapper, and the WirePlumber camera priority config. Multi-monitor on X11 is driven by `autorandr`; on sway it is driven by `kanshi` (config deployed via `host_sway_dotfiles`).

## Void Package And Dotfile Bucket Rules
The four Void desktop package lists in `ansible/inventory/group_vars/void.yml` are kept disjoint by role:
- `void_packages_base` — system runtime only (init/services, kernel, audio core, networking, filesystem, firewall, hardware daemons, runit logging).
- `desktop_common_packages` — WM-agnostic GUI infra (GTK theme, polkit, keyring, NM-applet, blueman, audio GUI, file manager backend + GVFS, portal, flatpak, printing/scanning).
- `desktop_i3_packages` / `desktop_sway_packages` — binaries specific to each session. Cross-WM packages used by both (`dunst`, `rofi`, `alacritty`) are intentionally duplicated in the two lists.
`profile_packages` in the same file is cross-distro and is overridden by `group_vars/server.yml` and the workstation group vars; do not move desktop-specific Void entries through it.
The dotfile vars follow the same split: `desktop_common_dotfiles` (in `group_vars/desktop.yml`) carries WM-agnostic GUI config and user scripts (Thunar, mimeapps, GTK theme setup, Udiskie, fontconfig, WirePlumber, mpv, …); `desktop_void_dotfiles` (in `group_vars/void.yml`) is reserved for files that need Void runtime (turnstile services, bash runit/dbus/ssh-agent fragments, `update-turnstile-env`).

## Workstation / Windows Notes
- Native Linux workstation hosts can combine `workstation_host_linux` with an OS-specific dev group.
- `deadalus-fedora` keeps GNOME managed settings in `ansible/inventory/host_vars/deadalus-fedora.yml`.
- Ubuntu workstation follow-up work is still open around YubiKey/GPG/SSH-FIDO2 package verification, GPG signing setup on the YubiKey, and evaluating `ed25519-sk` SSH key generation.
- `workstation_host_windows` runs with `gather_facts: false` and validates PSRP settings plus `windows_package_backend` before role execution.
- Windows taskbar pins are driven by `windows_taskbar_pins` in `ansible/inventory/group_vars/workstation_host_windows.yml`; validate identifiers from a real Windows session before changing them.

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
- Required collections currently include `ansible.posix`, `ansible.windows`, `community.general`, and `community.windows`.
- `.yamllint` treats `line-length` as a warning at 120 chars and disables `document-start` and `comments-indentation`.

## When Updating Docs
- Keep `README.md` and `AGENTS.md` aligned when workflows materially change.
- If you add a new operational area, also add the narrowest validation command for it.
- Call out checks you could not run and any follow-up verification needed.
