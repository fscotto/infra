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
- Ubuntu workstation: `deadalus-ubuntu`
- Fedora workstation: `deadalus-fedora`
- Ubuntu server: `prometheus`
- Workstation topology now supports explicit native Linux workstation targets for Ubuntu and Fedora, plus Windows 11 host + Ubuntu WSL dev as separate layers
- A single inventory host can intentionally participate in multiple plays by belonging to multiple groups; host identity and play layering are not 1:1
- The WSL dev environment is intended to be managed by running Ansible locally from inside the distro, while the Windows host is managed remotely via PSRP and Windows package installs default to `winget_psrp`
- Most hosts use `ansible_connection: local`
- Current playbook layering: `all:!workstation_host_windows -> dotfiles_common`, `void -> packages_void + services_runit + profile_desktop_common + profile_desktop_i3 + profile_desktop_sway + profile_desktop_hyprland + profile_desktop_host`, `workstation_dev_ubuntu -> packages_ubuntu + services_systemd + profile_workstation_dev_common`, `workstation_dev_fedora -> packages_fedora + services_systemd + profile_workstation_dev_common`, `workstation_host_linux -> profile_workstation_gnome`, `workstation_dev_wsl -> packages_ubuntu + services_systemd + profile_workstation_dev_common + profile_workstation_dev_wsl`, `workstation_host_windows -> profile_workstation_host_windows`, `ubuntu_server -> packages_ubuntu + services_systemd + profile_server`
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
- `secrets/.vault_pass.gpg` is the preferred optional local vault password file; `scripts/vault_password_client.sh` decrypts it with `gpg`
- `secrets/.vault_pass` remains supported as a legacy local fallback if `.vault_pass.gpg` is absent
- if neither local file exists, Ansible falls back to an interactive prompt via `scripts/vault_password_client.sh`

Core validation from the repo root:
```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus-ubuntu --check --diff
ansible-playbook ansible/site.yml --limit deadalus-fedora --check --diff
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
ansible-playbook ansible/site.yml --limit deadalus-ubuntu
ansible-playbook ansible/site.yml --limit deadalus-fedora
ansible-playbook ansible/site.yml --limit deadalus-wsl
ansible-playbook ansible/site.yml --limit prometheus
scripts/bootstrap_mail.sh
pwsh -File scripts/bootstrap_windows_workstation.ps1
```

## Single-Test Equivalents
Use the narrowest command matching the changed area.
- Playbook syntax only: `ansible-playbook ansible/site.yml --syntax-check`
- Single host dry run: `ansible-playbook ansible/site.yml --limit <host> --check --diff`
- Single host, selected tags: `ansible-playbook ansible/site.yml --limit <host> --tags <tag1>,<tag2> --check --diff`
- Single task restart point: `ansible-playbook ansible/site.yml --limit <host> --start-at-task "<task name>" --check --diff`
- Single role lint: `ansible-lint ansible/roles/<role>`
- Single YAML file lint: `yamllint ansible/path/to/file.yml`
- Waybar config validation: `python3 -m json.tool dotfiles/desktop/.config/waybar/config-sway.jsonc >/dev/null` and `python3 -m json.tool dotfiles/desktop/.config/waybar/config-hyprland.jsonc >/dev/null`
- Script syntax/lint: `sh -n scripts/bootstrap_mail.sh` and `shellcheck scripts/bootstrap_mail.sh`
- Windows bootstrap script parse check: `pwsh -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('scripts/bootstrap_windows_workstation.ps1', [ref]$null, [ref]$null)"`

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
- Use FQCN module names such as `ansible.builtin.copy`, `ansible.builtin.template`, `ansible.windows.win_powershell`, and `community.general.xbps`
- Prefer dedicated modules over `ansible.builtin.command` or `ansible.builtin.shell`
- Use `command` only when no module fits; use `shell` only when shell features are required
- When using `command` or `shell`, set `changed_when` and `failed_when` when defaults are misleading
- Prefer `ansible.builtin.import_tasks` for static task composition and `include_tasks` only for dynamic or conditional includes
- Keep task names imperative, descriptive, and stable enough for `--start-at-task`
- Tag tasks consistently with existing families such as `packages`, `services`, `dotfiles`, `gnome`, `wsl`, `vscode`, `nvidia`, and `dotfiles:*`
- Prefer `loop` with `loop_control.label` for multi-item tasks
- Use handlers for service restarts when configuration changes should trigger them

### Variables, Types, And Naming
- Use `snake_case` for vars, facts, registered values, and custom facts
- Follow existing families such as `common_packages`, `profile_packages`, `host_packages`, `desktop_common_packages`, `enabled_services`, `host_enabled_services`, `windows_winget_packages`, and `windows_vscode_extensions`
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
- Keep `dotfiles/desktop/.config/waybar/config-*.jsonc` effectively valid JSON
- Prefer POSIX `sh` for simple scripts; use Bash only when needed
- Use `set -eu` in POSIX shell scripts unless there is a clear reason not to
- Quote variable expansions unless intentional splitting is required

### Error Handling, Safety, And Idempotency
- Fail early with `ansible.builtin.fail` when prerequisites are missing
- Guard OS-specific, DE-specific, version-specific, and host-specific behavior with `when`
- Use `no_log: true` for passwords, tokens, private keys, and secret-bearing command results
- Use `failed_when: false` only for intentional probes
- Keep tasks non-interactive unless explicitly user-driven
- Avoid destructive changes in user homes unless clearly required
- For firewall changes, allow required access before enabling the firewall
- When running commands as the desktop user, set `become_user` and the required `HOME` or session environment explicitly

## Area-Specific Notes
- `profile_desktop_common` manages shared Void desktop bootstrap, `emptty`, PAM hooks, dotfiles, mail bootstrap, and shared desktop tooling
- `profile_desktop_i3` contains the X11/i3 session pieces
- `profile_desktop_sway` contains the wlroots/Sway session pieces and deploys shared Sway + Waybar dotfiles
- `profile_desktop_hyprland` contains the optional Hyprland/Wayland session pieces
- `profile_desktop_host` carries host-specific desktop overrides such as NVIDIA, PRIME wrappers, and host-only WirePlumber config
- `profile_workstation_dev_common` carries the shared dev layer for native Linux workstation profiles plus Ubuntu WSL
- `packages_fedora` manages the Fedora workstation package catalog, including Docker and Google Chrome repos, VS Code via the Microsoft RPM repo, IntelliJ IDEA Ultimate via COPR, and the remaining workstation GUI apps via Flatpak
- `profile_workstation_gnome` carries Linux host-only GNOME setup, extensions, firewall enablement, and host-managed `gsettings`
- Native Linux workstation plays can be combined on the same inventory host when that host is placed in both the relevant OS/dev group and `workstation_host_linux`
- `deadalus-fedora` keeps Fedora-specific `workstation_gnome_managed_settings` in `ansible/inventory/host_vars/deadalus-fedora.yml`, derived from the real host state and intentionally separate from Ubuntu
- `profile_workstation_dev_wsl` carries WSL-specific Ubuntu tweaks such as `systemd` and PSRP Python dependencies
- `profile_workstation_host_windows` manages the Windows 11 host via PSRP over HTTPS using `negotiate` by default, installs host applications via `winget` with a configurable `windows_package_backend` defaulting to `winget_psrp`, applies Windows shell tweaks, manages taskbar pins through a local Start layout policy with `PinListPlacement="Replace"`, and sets Windows Terminal's default profile to Ubuntu
- `deadalus-wsl` is modeled as a local inventory target intended to be run from inside the Ubuntu WSL distro
- Windows taskbar pinning is driven by the ordered `windows_taskbar_pins` list in `ansible/inventory/group_vars/workstation_host_windows.yml`; validate identifiers from a real Windows session before changing that list
- Do not auto-restart `emptty` during playbook runs on active desktop hosts; prefer a manual restart from SSH or another TTY after the run
- `dotfiles/desktop/.xinitrc` affects X11 login behavior
- `dotfiles/desktop/.local/bin/start-sway-session` and `start-hyprland-session` are critical session bootstrap paths
- `nymph` has special NVIDIA/PRIME handling, host-specific WirePlumber camera config, host-specific Sway overrides, and deterministic workspace placement via `kanshi`

## Planned Windows Backend Expansion
This section captures agreed future design decisions for adding a third explicit Windows package backend using Chocolatey. It is planning context only and does not describe current repository behavior beyond what is already implemented.

### Agreed Design Decisions
- Add `chocolatey` as a third explicit `windows_package_backend` alongside `winget_psrp` and `winget_wsl_local`
- Keep backend selection explicit per host; do not implement Chocolatey as an automatic fallback from winget
- Keep `winget_psrp` as the default backend unless overridden through inventory, extra vars, or vault
- Use an internal or proxy Chocolatey feed, not the public community feed directly
- Allow automatic Chocolatey bootstrap if `choco.exe` is missing
- Fail fast when the selected backend does not have a package mapping for a requested Windows package

### Planned Data Model
- Replace the current `windows_winget_packages`-only model with a backend-neutral catalog such as `windows_packages`
- Recommended shape:

```yaml
windows_packages:
  - key: sevenzip
    name: 7-Zip
    winget:
      id: 7zip.7zip
    chocolatey:
      name: 7zip

  - key: whatsapp
    name: WhatsApp
    winget:
      id: 9NKSQGP7F2NH
      source: msstore
```

- The selected backend should consume only its own nested mapping
- If `windows_package_backend == 'chocolatey'` and a package lacks a `chocolatey` mapping, fail before installation starts
- Keep backend-specific fields nested under backend keys rather than mixing them at top level

### Planned Variables
- Extend `windows_package_backend` to accept `chocolatey`
- Add `windows_chocolatey_source_name`
- Add `windows_chocolatey_source_url`
- Add optional vault-backed Chocolatey source credentials if the internal or proxy feed requires authentication

### Planned Implementation Areas
- `ansible/site.yml`: extend backend validation to support `chocolatey`
- `ansible/roles/profile_workstation_host_windows/tasks/main.yml`: add an explicit Chocolatey code path, bootstrap Chocolatey when missing, configure the internal or proxy source, validate package mappings, and install packages with `chocolatey.chocolatey.win_chocolatey`
- `ansible/inventory/group_vars/workstation_host_windows.yml`: migrate package data from `windows_winget_packages` to a backend-neutral catalog and add non-secret Chocolatey source settings if appropriate
- `ansible/collections/requirements.yml`: add the `chocolatey.chocolatey` collection
- `README.md`, `AGENTS.md`, and `secrets/vault.yml.example`: document backend selection and Chocolatey source variables

### Package Coverage Notes For First Iteration
- Likely good first Chocolatey candidates: `7zip`, `adobereader`, `dbeaver`, `googlechrome`, `intellijidea-ultimate`, `logioptionsplus`, `vscode`, `postman`, and `telegram`
- Treat `WhatsApp` as not covered until a valid non-deprecated Chocolatey package is confirmed
- Treat `Windows Terminal` as not covered until a stable Chocolatey package mapping is confirmed
- Because the agreed behavior is fail-fast on missing mappings, `windows_package_backend=chocolatey` should fail if unsupported packages remain requested without a valid Chocolatey mapping

### Source Strategy
- First implementation should target an internal or proxy Chocolatey feed rather than fully internalized packages
- This is acceptable as a faster first phase, but it is less deterministic long term than full internalization

### Validation Expectations For This Future Work
Minimum:

```bash
ansible-playbook ansible/site.yml --syntax-check
```

Backend-specific dry runs:

```bash
ansible-playbook ansible/site.yml --limit deadalus-win --check --diff -e windows_package_backend=winget_psrp
ansible-playbook ansible/site.yml --limit deadalus-win --check --diff -e windows_package_backend=winget_wsl_local
ansible-playbook ansible/site.yml --limit deadalus-win --check --diff -e windows_package_backend=chocolatey
```

Targeted non-check validation once feed details exist:

```bash
ansible-playbook ansible/site.yml --limit deadalus-win --tags packages -e windows_package_backend=chocolatey
```

### Remaining Open Detail
- The concrete internal or proxy repository product and source details still need to be supplied when this work is implemented, for example Nexus, Artifactory, ProGet, or another NuGet-compatible proxy

## Validation Expectations Before Finishing
Default minimum:
```bash
ansible-playbook ansible/site.yml --syntax-check
```

Run a host-limited dry run whenever the change affects a real host profile, package set, service set, session, PAM stack, templates, or dotfiles.

For workstation changes, prefer:
```bash
ansible-playbook ansible/site.yml --limit deadalus-ubuntu --check --diff
ansible-playbook ansible/site.yml --limit deadalus-fedora --check --diff
ansible-playbook ansible/site.yml --limit deadalus-wsl --check --diff
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
- Prefer host-limited validation first: `ikaros` or `nymph` for Void desktop work, `deadalus-ubuntu` for Ubuntu workstation work, `deadalus-fedora` for Fedora workstation work, and `prometheus` for server work
- Call out checks you could not run and any follow-up verification needed
