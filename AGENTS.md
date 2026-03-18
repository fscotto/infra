# AGENTS.md
Guidance for agentic coding tools working in this repository.
Project type: Ansible-based infrastructure plus managed dotfiles.

## Repository snapshot
- Entry playbook: `ansible/site.yml`
- Ansible config: `ansible.cfg`
- Inventory: `ansible/inventory/hosts.yml`
- Group vars: `ansible/inventory/group_vars/*.yml`
- Host vars: `ansible/inventory/host_vars/*.yml`
- Roles: `ansible/roles/*/tasks/main.yml`
- Dotfiles source of truth: `dotfiles/`
- Scripts: `scripts/`
- Sensitive local material/examples: `secrets/`
- Active orchestration: `all -> dotfiles_common`; `void -> packages_void, services_runit, profile_desktop_i3`
- Roles present but not currently wired into `ansible/site.yml`: `base`, `dotfiles`, `packages_ubuntu`, `services_systemd`, `profile_workstation_gnome`, `profile_server`

## Local instruction files
Checked in this repository when this file was written:
- `.cursorrules`: not present
- `.cursor/rules/`: not present
- `.github/copilot-instructions.md`: not present
If any of these appear later, treat them as higher-priority local instructions.

## Working assumptions
- Favor idempotent, host-safe changes over cleverness.
- Preserve the intended layering: `all -> OS -> profile -> host`.
- Validate on one host before broad rollout.
- The repo contains both first-party dotfiles and vendored third-party plugin code.

## Build, lint, and test commands
There is no compile/build step. Validation is Ansible syntax checks, inventory inspection, dry-runs, and linting.
Install base tooling if needed:
```bash
python3 -m pip install ansible
```
Core commands:
```bash
ansible-playbook ansible/site.yml
ansible-playbook ansible/site.yml --check --diff
ansible-playbook ansible/site.yml --limit ikaros
ansible-playbook ansible/site.yml --limit nymph
ansible-playbook ansible/site.yml --syntax-check
ansible-inventory --graph
ansible-inventory --host ikaros
```
Linting if available locally:
```bash
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

## Single-test equivalents
There is no Molecule, pytest, or dedicated unit-test suite. Use these as the closest equivalent to a single targeted test.
Fastest confidence check:
```bash
ansible-playbook ansible/site.yml --syntax-check
```
Best default host-scoped safety check:
```bash
ansible-playbook ansible/site.yml --limit ikaros --check --diff
```
Start from one task when validating a narrow change:
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Copy common dotfiles" --check --diff
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Install Void nonfree repository if needed" --check --diff
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Copy desktop dotfiles" --check --diff
```
Inventory-only resolution for one machine:
```bash
ansible-inventory --host ikaros
```
Notes:
- Keep task names stable and unique enough for `--start-at-task`.
- Prefer `--check --diff` before package, service, PAM, or session changes.
- Use `--limit` aggressively to avoid accidental multi-host rollout.

## Code style guidelines
### General principles
- Prefer minimal, scoped changes that match the existing layout.
- Preserve idempotency and avoid hidden mutable state.
- Prefer declarative modules over imperative commands.
- Keep orchestration in playbooks and implementation in roles.
- Avoid unrelated refactors while solving a targeted task.

### Ansible modules and task structure
- Use FQCN module names such as `ansible.builtin.copy` and `community.general.xbps`.
- Prefer purpose-built modules over `ansible.builtin.command` or `ansible.builtin.shell`.
- Use `command` only when no good module exists.
- Use `shell` only when shell features are genuinely required.
- When using `command` or `shell`, set `changed_when` and `failed_when` when defaults are misleading.
- Keep task names imperative, outcome-based, and unique enough to support `--start-at-task`.

### YAML formatting
- Start YAML files with `---`.
- Use 2-space indentation; do not use tabs.
- Keep lists and maps in stable, readable order.
- Quote file modes as strings: `"0644"`, `"0755"`, `"0600"`, `"0700"`.
- Prefer multiline Jinja when a one-line expression becomes hard to read.
- Avoid formatting-only churn in untouched sections.

### Variables, types, and templating
- Use `snake_case` consistently.
- Follow existing naming families like `common_packages`, `profile_packages`, and `host_packages`.
- Keep booleans as booleans, not quoted strings.
- Keep structured data as YAML collections, not comma-separated strings.
- Guard optional values with `default([])`, `default({})`, or `default('')` as appropriate.
- Build user paths from `{{ user_home }}` instead of hardcoding home directories.

### Naming conventions
- Role names stay lowercase with underscores.
- Inventory groups and matching var files should stay semantically aligned.
- New variables should fit existing patterns instead of inventing one-off names.

### Error handling and safety
- Guard OS-specific or profile-specific behavior with `when` clauses.
- Prefer explicit loops and inputs over assumptions.
- Do not suppress failures without a clear operational reason.
- Use `failed_when: false` only for intentional state probes.
- Keep tasks non-interactive and automation-safe.
- Avoid destructive operations in user homes unless the request clearly requires them.

### Dotfiles and script conventions
- Prefer POSIX `sh` for simple login/session scripts.
- Use Bash only when Bash features are required; then use `#!/usr/bin/env bash`.
- Quote variable expansions unless intentional word splitting is required.
- Preserve executable bits for deployed scripts where appropriate.
- Keep session-start changes conservative; verify startup paths and environment assumptions.

### Imports and external code
- There are no Python import conventions to optimize for here; most changes are YAML and shell.
- Treat `dotfiles/common/.tmux/plugins/` as vendored upstream code unless the task explicitly targets it.
- Prefer changing first-party wrapper/config files before patching vendored plugin internals.

## Editing guidance by area
- `ansible/site.yml`: keep it small and orchestration-focused.
- `ansible/inventory/group_vars/*.yml`: shared defaults by layer.
- `ansible/inventory/host_vars/*.yml`: host-specific overrides only.
- `ansible/roles/*/tasks/main.yml`: role implementation details.
- `dotfiles/`: user-facing config and session scripts deployed by roles.
- `secrets/vault.yml`: treat as sensitive; do not expose values in tracked plain text.

## Validation expectations before finishing
Run the narrowest useful checks for the area you changed.
Default minimum:
```bash
ansible-playbook ansible/site.yml --syntax-check
```
Preferred for role or vars changes:
```bash
ansible-playbook ansible/site.yml --limit <host> --check --diff
```
Useful supporting checks:
```bash
ansible-inventory --graph
ansible-inventory --host <host>
ansible-lint ansible/site.yml
yamllint ansible/
```

## Agent workflow expectations
- Read the relevant inventory, vars, role tasks, and deployed dotfiles before editing.
- Do not change unrelated files to "clean things up".
- Keep README and AGENTS aligned when workflows materially change.
- If you add a new operational area, also add the validation command agents should run.
- Prefer host-limited validation before broad apply.
- Call out any verification you could not run.
