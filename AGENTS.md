# AGENTS.md
Guidance for coding agents working in this repository.
Project type: Ansible-driven infrastructure, workstation/server provisioning, and user dotfiles.

## Repository Map
- Entry playbook: `ansible/site.yml`
- Inventory: `ansible/inventory/hosts.yml`
- Group vars: `ansible/inventory/group_vars/*.yml`
- Host vars: `ansible/inventory/host_vars/*.yml`
- Shared templates: `ansible/templates/**/*.j2`
- Roles: `ansible/roles/*`
- Role assets: `ansible/roles/*/{tasks,templates,files,handlers}/`
- Dotfiles: `dotfiles/`
- Scripts: `scripts/`
- Secrets: `secrets/`

## Topology And Orchestration
- Void desktops: `ikaros`, `nymph`
- Ubuntu workstation: `deadalus`
- Ubuntu server: `prometheus`
- Workstation topology now supports Linux host + Ubuntu dev and Windows host + Ubuntu WSL dev as separate layers
- The WSL dev environment is intended to be managed by running Ansible locally from inside the distro, while the Windows host is managed remotely via PSRP
- Most hosts use `ansible_connection: local`
- Current playbook layering: `all:!workstation_host_windows -> dotfiles_common`, `void -> packages_void + services_runit + profile_desktop_common + profile_desktop_i3 + profile_desktop_sway + profile_desktop_hyprland + profile_desktop_host`, `workstation_dev_ubuntu -> packages_ubuntu + services_systemd + profile_workstation_dev_common`, `workstation_host_linux -> profile_workstation_gnome`, `workstation_dev_wsl -> packages_ubuntu + services_systemd + profile_workstation_dev_common + profile_workstation_dev_wsl`, `workstation_host_windows -> profile_workstation_host_windows`, `ubuntu_server -> packages_ubuntu + services_systemd + profile_server`
- Present but currently unwired roles: `base`, `dotfiles`

## Local Instruction Files
Checked when this file was updated:
- `.cursorrules`: not present
- `.cursor/rules/`: not present
- `.github/copilot-instructions.md`: not present
If any of these files appear later, treat them as higher-priority repo-local instructions.

## Working Principles
- Preserve the layering `all -> OS -> profile -> host`
- Prefer minimal, targeted edits over cleanup or refactors
- Preserve idempotency and reproducibility
- Validate on one limited host before broad rollout
- Treat `secrets/` as sensitive; never print secret values
- Avoid editing vendored code under `dotfiles/desktop/.tmux/plugins/` unless explicitly asked
- Keep `ansible/site.yml` small; orchestration belongs there, implementation belongs in roles
- Read the relevant inventory, vars, role tasks, templates, files, handlers, and dotfiles before editing

## Build, Lint, And Test Commands
There is no compile/build pipeline. Confidence comes from syntax checks, dry runs, linting, and targeted shell validation.

Install tooling if needed:
```bash
python3 -m pip install ansible ansible-lint yamllint shellcheck-py
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

Vault handling:
- `secrets/vault.yml` is the shared encrypted vars file
- `secrets/vault.local.yml` is an optional machine-local encrypted override file and should stay untracked
- `secrets/.vault_pass` is an optional local password file; if absent, Ansible falls back to an interactive prompt via `scripts/vault_password_client.sh`

Core validation from the repo root:
```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus --check --diff
ansible-playbook ansible/site.yml --limit deadalus-wsl --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

Useful execution commands:
```bash
ansible-playbook ansible/site.yml
ansible-playbook ansible/site.yml --limit ikaros
ansible-playbook ansible/site.yml --limit nymph
ansible-playbook ansible/site.yml --limit deadalus
ansible-playbook ansible/site.yml --limit deadalus-wsl
ansible-playbook ansible/site.yml --limit prometheus
scripts/bootstrap_mail.sh
pwsh -File scripts/bootstrap_windows_workstation.ps1
```

## Single-Test Equivalents
There is no pytest, Molecule, or unit-test suite. Use the narrowest command matching the changed area.
- Playbook syntax only: `ansible-playbook ansible/site.yml --syntax-check`
- Single host dry run: `ansible-playbook ansible/site.yml --limit <host> --check --diff`
- Single host, selected tags: `ansible-playbook ansible/site.yml --limit <host> --tags <tag1>,<tag2> --check --diff`
- Single task restart point: `ansible-playbook ansible/site.yml --limit <host> --start-at-task "<task name>" --check --diff`
- Single role lint: `ansible-lint ansible/roles/<role>`
- Single YAML file lint: `yamllint ansible/path/to/file.yml`
- Waybar config validation: `python3 -m json.tool dotfiles/desktop/.config/waybar/config-sway.jsonc >/dev/null` and `python3 -m json.tool dotfiles/desktop/.config/waybar/config-hyprland.jsonc >/dev/null`
- Script syntax/lint: `sh -n scripts/bootstrap_mail.sh` and `shellcheck scripts/bootstrap_mail.sh`
- Windows bootstrap script parse check: `pwsh -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('scripts/bootstrap_windows_workstation.ps1', [ref]$null, [ref]$null)"`
- For shell changes outside vendored tmux plugins, prefer validating the touched file with `sh -n` and `shellcheck`
- Prefer one limited-host dry run for vars, templates, dotfiles, packages, services, PAM, display manager, and firewall changes

## Code Style Guidelines
### General
- Keep orchestration in playbooks and implementation in roles
- Prefer declarative modules over imperative shell commands
- Make state transitions explicit
- Avoid unrelated refactors in the same change
- Keep comments sparse and only for non-obvious behavior

### YAML And Formatting
- Start YAML files with `---`
- Use 2-space indentation; never use tabs
- Keep existing ordering stable when editing lists and maps
- Quote file modes as strings such as `"0644"`, `"0755"`, `"0600"`, `"0700"`
- Avoid formatting-only churn in untouched sections

### Modules, Imports, And Task Structure
- Use FQCN module names such as `ansible.builtin.copy`, `ansible.builtin.template`, and `community.general.xbps`
- Prefer dedicated modules over `ansible.builtin.command` or `ansible.builtin.shell`
- Use `command` only when no module fits; use `shell` only when shell features are required
- When using `command` or `shell`, set `changed_when` and `failed_when` when defaults are misleading
- Prefer `ansible.builtin.import_tasks` for static task composition and `include_tasks` only for dynamic or conditional includes
- Keep task names imperative, descriptive, and stable enough for `--start-at-task`
- Tag tasks consistently with existing families such as `packages`, `services`, `dotfiles`, `gnome`, `nvidia`, `emptty`, and `dotfiles:*`
- Prefer `loop` with `loop_control.label` for multi-item tasks
- Use handlers for service restarts when configuration changes should trigger them

### Variables, Types, And Naming
- Use `snake_case` for vars, facts, registered values, and custom facts
- Follow existing families such as `common_packages`, `profile_packages`, `host_packages`, `desktop_common_packages`, `desktop_i3_packages`, `desktop_sway_packages`, `desktop_hyprland_packages`, `desktop_common_dotfiles`, `desktop_i3_dotfiles`, `desktop_sway_dotfiles`, `desktop_hyprland_dotfiles`, `host_i3_dotfiles`, `host_sway_dotfiles`, `host_hyprland_dotfiles`, `enabled_services`, and `host_enabled_services`
- Keep booleans as booleans, not quoted strings
- Keep structured values as YAML lists/maps, not comma-separated strings
- Guard optional lists with `default([])`, mappings with `default({})`, and strings with `default('')`
- Build managed-user paths from `{{ user_home }}` where applicable
- Put host-specific overrides in `host_vars`, not shared `group_vars`

### Templates, Dotfiles, And Shell
- Keep secrets parameterized through vars; never hardcode them in templates or dotfiles
- Prefer role `templates/` for variable-driven config and role `files/` for static payloads
- Preserve destination paths and permissions unless the task requires a change
- Dotfiles should stay deployable on real machines; avoid repo-only hacks in `dotfiles/`
- Keep `dotfiles/desktop/.config/waybar/config-*.jsonc` effectively valid JSON even though the format is JSONC, so simple `python3 -m json.tool` validation continues to work
- Prefer POSIX `sh` for simple scripts; use Bash only when needed
- Use `set -eu` in POSIX shell scripts unless there is a clear reason not to
- Quote variable expansions unless intentional splitting is required
- Do not modernize vendored shell code under tmux plugins unless explicitly asked

### Error Handling, Safety, And Idempotency
- Fail early with `ansible.builtin.fail` when prerequisites are missing
- Guard OS-specific, DE-specific, and host-specific behavior with `when`
- Use `no_log: true` for passwords, tokens, private keys, and secret-bearing command results
- Use `failed_when: false` only for intentional probes
- Keep tasks non-interactive unless explicitly user-driven
- Avoid destructive changes in user homes unless clearly required
- For firewall changes, allow required access before enabling the firewall
- Be careful with display-manager and session changes on desktop hosts; validate on one host first
- When running commands as the desktop user, set `become_user` and the required `HOME` or session environment explicitly

## Area-Specific Notes
- `profile_desktop_common` manages shared Void desktop bootstrap, `emptty`, PAM hooks, dotfiles, mail bootstrap, and shared desktop tooling
- `profile_desktop_i3` contains the X11/i3 session pieces
- `profile_desktop_sway` contains the wlroots/Sway session pieces and deploys shared Sway + Waybar dotfiles
- `profile_desktop_hyprland` contains the optional Hyprland/Wayland session pieces
- `profile_desktop_host` carries host-specific desktop overrides such as NVIDIA, PRIME wrappers, and host-only WirePlumber config
- `profile_workstation_dev_common` carries the Ubuntu dev layer shared by native workstation and WSL Ubuntu
- `profile_workstation_gnome` now carries Linux host-only GNOME setup, extensions, and UFW
- `profile_workstation_dev_wsl` carries WSL-specific Ubuntu tweaks such as `systemd`
- `profile_workstation_host_windows` manages the Windows host via PSRP over HTTPS using `negotiate` by default and installs host applications via `winget` called from `win_powershell`
- `deadalus-wsl` is modeled as a local inventory target intended to be run from inside the Ubuntu WSL distro
- Do not auto-restart `emptty` during playbook runs on active desktop hosts; prefer a manual restart from SSH or another TTY after the run
- `dotfiles/desktop/.xinitrc` is part of the X11 session bootstrap path; changes there affect login behavior
- `dotfiles/desktop/.local/bin/start-sway-session` is the Sway session bootstrap path; keep it aligned with DBus, keyring, and host-specific environment overrides
- `dotfiles/desktop/.local/bin/start-hyprland-session` is the Wayland session bootstrap path; keep it aligned with DBus and keyring expectations
- Waybar is split by compositor: `dotfiles/desktop/.config/waybar/config-sway.jsonc` for Sway, `config-hyprland.jsonc` for Hyprland, and `style.css` is shared; do not mix `sway/*` and `hyprland/*` modules in the same config
- `nymph` has special NVIDIA/PRIME handling, a host-specific WirePlumber camera override, host-specific Sway environment overrides, and host-specific `kanshi` monitor policy; keep host logic guarded by hostname or host vars
- On `nymph`, Sway workspace placement is intentionally deterministic: in dual-monitor mode workspace `1` belongs to `eDP-1` and workspaces `2-10` belong to `DP-1`; in laptop-only mode all workspaces collapse back to `eDP-1` via `kanshi` `exec` hooks

## Validation Expectations Before Finishing
Default minimum:
```bash
ansible-playbook ansible/site.yml --syntax-check
```
Run a host-limited dry run whenever the change affects a real host profile, package set, service set, session, PAM stack, templates, or dotfiles.
If you touched Sway or Hyprland Waybar config, also run:
```bash
python3 -m json.tool dotfiles/desktop/.config/waybar/config-sway.jsonc >/dev/null
python3 -m json.tool dotfiles/desktop/.config/waybar/config-hyprland.jsonc >/dev/null
```
If you touched `scripts/bootstrap_mail.sh`, also run:
```bash
sh -n scripts/bootstrap_mail.sh
shellcheck scripts/bootstrap_mail.sh
```
If you touched `scripts/bootstrap_windows_workstation.ps1`, also run:
```bash
pwsh -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('scripts/bootstrap_windows_workstation.ps1', [ref]$null, [ref]$null)"
```

## Agent Workflow Expectations
- Do not revert unrelated worktree changes made by the user
- Keep `README.md` and `AGENTS.md` aligned when workflows materially change
- If you add a new operational area, also add the validation command agents should run
- Prefer host-limited validation first: `ikaros` or `nymph` for Void desktop work, `deadalus` for Ubuntu workstation work, and `prometheus` for server work
- Call out checks you could not run and any follow-up verification needed
