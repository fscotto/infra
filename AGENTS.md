# AGENTS.md

Ansible-driven personal infrastructure repo for Void desktops, Linux workstations, Windows+WSL, and an Ubuntu server.

## Source Of Truth
- Main orchestration: `ansible/site.yml`
- Inventory and layering inputs: `ansible/inventory/hosts.yml`, `ansible/inventory/group_vars/*.yml`, `ansible/inventory/host_vars/*.yml`
- Dotfiles live under `dotfiles/`
- OpenCode loads global instructions from `dotfiles/desktop/.config/opencode/opencode.json`

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

## Desktop Void Notes
- `profile_desktop_common` owns the shared desktop bootstrap.
- `.emacs.d` is deployed by a dedicated `profile_desktop_common` task tagged `emacs`.
- User services are managed by `turnstile` and live under `dotfiles/desktop/.config/service/`.
- `desktop_ollama_enabled` controls whether the user `ollama` service is present; default is `false` and hosts can override it in `host_vars`.
- `ssh-agent` runs under `turnstile` with stable socket `~/.local/state/ssh-agent/socket`.
- Critical session entrypoints:
  - `dotfiles/desktop/.xinitrc`
  - `dotfiles/desktop/.local/bin/start-sway-session`
- Do not auto-restart `emptty` during playbook runs on active desktop hosts; restart it manually from another TTY/SSH session if needed.

## Workstation / Windows Notes
- Native Linux workstation hosts can combine `workstation_host_linux` with an OS-specific dev group.
- `deadalus-fedora` keeps GNOME managed settings in `ansible/inventory/host_vars/deadalus-fedora.yml`.
- Ubuntu workstation follow-up work is still open around YubiKey/GPG/SSH-FIDO2 package verification, GPG signing setup on the YubiKey, and evaluating `ed25519-sk` SSH key generation.
- `workstation_host_windows` runs with `gather_facts: false` and validates PSRP settings plus `windows_package_backend` before role execution.
- Windows taskbar pins are driven by `windows_taskbar_pins` in `ansible/inventory/group_vars/workstation_host_windows.yml`; validate identifiers from a real Windows session before changing them.

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
