# AGENTS.md
Guidance for agentic coding tools working in this repository.
Project type: Ansible-based infrastructure and user dotfiles.

## Repository snapshot
- Entry playbook: `ansible/site.yml`
- Inventory: `ansible/inventory/hosts.yml`
- Group vars: `ansible/inventory/group_vars/*.yml`
- Host vars: `ansible/inventory/host_vars/*.yml`
- Templates: `ansible/templates/**/*.j2`
- Dotfiles source of truth: `dotfiles/`
- Utility scripts: `scripts/`
- Sensitive material/examples: `secrets/`

## Active orchestration
`ansible/site.yml` currently applies:
- `all -> dotfiles_common`
- `void -> packages_void, services_runit, profile_desktop_i3`
- `ubuntu_workstation -> packages_ubuntu, services_systemd, profile_workstation_gnome`
- `ubuntu_server -> packages_ubuntu, services_systemd, profile_server`

Active roles:
- `dotfiles_common`, `packages_void`, `services_runit`, `profile_desktop_i3`, `packages_ubuntu`, `services_systemd`, `profile_workstation_gnome`, `profile_server`

Roles present but not wired into `ansible/site.yml`:
- `base`
- `dotfiles`

## Local instruction files
Checked in this repository when this file was written:
- `.cursorrules`: not present
- `.cursor/rules/`: not present
- `.github/copilot-instructions.md`: not present
If any of these appear later, treat them as higher-priority local instructions.

## Working assumptions
- Favor idempotent, host-safe changes over cleverness.
- Preserve the layering: `all -> OS -> profile -> host`.
- Validate on one host before broad rollout.
- Prefer minimal, targeted edits over cleanup refactors.
- Treat `secrets/` as sensitive and avoid exposing values.
- `dotfiles/common/.tmux/plugins/` contains vendored upstream code.

## Build, lint, and test commands
There is no compile/build step. Validation is based on syntax checks, inventory inspection, dry-runs, and linting.

Install tooling if needed:
```bash
python3 -m pip install ansible
ansible-galaxy collection install community.general
```

Linting and static checks if available locally:
```bash
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
sh -n scripts/bootstrap_mail.sh
shellcheck scripts/bootstrap_mail.sh
```

## Single-test equivalents
There is no Molecule, pytest, or dedicated unit-test suite. Use the narrowest validation that matches the change.

Fastest confidence check:
```bash
ansible-playbook ansible/site.yml --syntax-check
```

Best default dry-runs:
```bash
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit deadalus --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff
```

Testing notes:
- Prefer `--limit` aggressively to avoid accidental multi-host rollout.
- Prefer `--check --diff` before package, service, PAM, bootloader, firewall, or session changes.
- Keep task names stable and unique enough for `--start-at-task`.
- If you change only vars, inventory inspection may be the quickest useful check.

## Code style guidelines
### General principles
- Keep orchestration in playbooks and implementation details in roles.
- Prefer declarative modules over imperative commands.
- Avoid unrelated refactors while solving a targeted task.
- Preserve idempotency and make state transitions explicit.

### Ansible modules and task structure
- Use FQCN module names such as `ansible.builtin.copy` and `community.general.ufw`.
- Prefer purpose-built modules over `ansible.builtin.command` or `ansible.builtin.shell`.
- Use `command` only when no good module exists; use `shell` only when shell features are required.
- When using `command` or `shell`, set `changed_when` and `failed_when` when defaults are misleading.
- Keep task names imperative, outcome-based, and unique enough for `--start-at-task`.
- Tag every task consistently with its execution flow, typically `packages`, `services`, `dotfiles`, `gnome`, `nvidia`, or `dotfiles:*`.
- Prefer `loop` with clear `loop_control.label` for user-facing collections.

### YAML formatting
- Start YAML files with `---`.
- Use 2-space indentation and never tabs.
- Keep keys, lists, and maps in stable order.
- Quote file modes as strings: `"0644"`, `"0755"`, `"0600"`, `"0700"`.
- Avoid formatting-only churn in untouched sections.

### Variables, types, and naming
- Use `snake_case` consistently for variables and facts.
- Follow existing families such as `common_packages`, `profile_packages`, `host_packages`, `common_dotfiles`, `workstation_dotfiles`, `server_dotfiles`, and `host_dotfiles`.
- Keep booleans as booleans, not quoted strings.
- Keep structured data as YAML collections, not comma-separated strings.
- Guard optional collections/maps with `default([])` and `default({})`.
- Guard optional strings with `default('')`.
- Build user paths from `{{ user_home }}` instead of hardcoding home directories.
- Host-specific overrides belong in `host_vars`, not shared group files.

### Error handling and safety
- Guard OS-specific or profile-specific behavior with `when` clauses.
- Prefer explicit inputs over assumptions about host state.
- Use `failed_when: false` only for intentional probes or best-effort detection.
- Use `no_log: true` for secrets, passwords, and sensitive command results.
- Keep tasks non-interactive and automation-safe.
- Avoid destructive operations in user homes unless clearly required.
- Fail early with `ansible.builtin.fail` when prerequisites such as architecture, release metadata, or session bus data are missing.
- For firewall changes, allow required access before enabling the firewall.

### Shell, scripts, and external code
- Prefer POSIX `sh` for simple scripts; use Bash only when Bash features are required.
- Quote variable expansions unless intentional word splitting is required.
- Preserve executable bits for deployed scripts where appropriate.
- If you add Python later, follow standard-library, third-party, local import grouping.
- Treat vendored tmux plugins as upstream code unless the task explicitly targets them.

## Editing guidance by area
- `ansible/site.yml`: keep it small and orchestration-focused.
- `ansible/inventory/group_vars/*.yml`: shared defaults by layer.
- `ansible/inventory/host_vars/*.yml`: host-specific overrides only.
- `ansible/roles/*/tasks/main.yml`: role implementation details.
- `ansible/templates/**/*.j2`: keep secrets and host-specific values parameterized.
- `dotfiles/`: user-facing config and session scripts deployed by roles.
- `scripts/`: standalone local utilities; keep them safe to run manually.

## Validation expectations before finishing
Run the narrowest useful checks for the area you changed.

Default minimum:
```bash
ansible-playbook ansible/site.yml --syntax-check
```

Preferred for role, template, or vars changes:
```bash
ansible-playbook ansible/site.yml --limit <host> --check --diff
```

## Agent workflow expectations
- Read the relevant inventory, vars, role tasks, templates, and deployed dotfiles before editing.
- Do not change unrelated files to "clean things up".
- Keep `README.md` and `AGENTS.md` aligned when workflows materially change.
- If you add a new operational area, also add the validation command agents should run.
- Prefer host-limited validation before broad apply.
- Call out any verification you could not run.
