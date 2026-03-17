# AGENTS.md

Guidance for coding agents working in this repository.
Project type: Ansible infrastructure + managed dotfiles.

## Repository scope and layout
- Entry playbook: `ansible/site.yml`
- Inventory: `ansible/inventory/hosts.yml`
- Group vars: `ansible/inventory/group_vars/*.yml`
- Host vars: `ansible/inventory/host_vars/*.yml`
- Roles: `ansible/roles/*/tasks/main.yml`
- Dotfiles source of truth: `dotfiles/`
- Ansible config file: `ansible.cfg`

Current `ansible.cfg` defaults:
- `inventory = ansible/inventory/hosts.yml`
- `roles_path = ansible/roles`
- `host_key_checking = False`
- `retry_files_enabled = False`

## Local instruction files (Cursor/Copilot)
Checked in this repository:
- `.cursorrules`: not present
- `.cursor/rules/`: not present
- `.github/copilot-instructions.md`: not present

If any of the files above appear later, treat them as higher-priority local instructions.

## Build, lint, and test commands
There is no compile/build step in this repo.
Validation is Ansible syntax checks, dry-runs, inventory checks, and linting.

Core apply run:
```bash
ansible-playbook ansible/site.yml
```

Safe dry-run with changes preview:
```bash
ansible-playbook ansible/site.yml --check --diff
```

Target a single host (useful for SSH-first rollout):
```bash
ansible-playbook ansible/site.yml --limit ikaros
```

Linting (if installed locally):
```bash
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

## Single-test equivalents (important)
There is no Molecule/pytest suite.
Use one of these as a "single test" workflow.

Fast syntax-only validation:
```bash
ansible-playbook ansible/site.yml --syntax-check
```

Best default single-host safety check:
```bash
ansible-playbook ansible/site.yml --limit nymph --check --diff
```

Single-role smoke test using `--start-at-task` (dotfiles path):
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Copy common dotfiles" --check --diff
```

Single-role smoke test using `--start-at-task` (Void packages path):
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Install Void nonfree repository if needed" --check --diff
```

Notes:
- Current active stack in `ansible/site.yml`: `dotfiles_common`, `packages_void`, `services_runit`, `profile_desktop_i3`.
- Ubuntu/systemd/workstation/server roles exist in the repo but are not currently included by `ansible/site.yml`.
- Minimum dependencies: Python 3, Ansible, target host access (local or SSH). Setup: `python3 -m pip install ansible`.

## Code style guidelines

### Core principles
- Prefer declarative, idempotent, host-safe automation.
- Keep layering explicit: `all -> OS -> profile -> host`.
- Keep changes minimal, scoped, and reversible.
- Avoid speculative refactors unrelated to the requested task.


### Modules, imports, and task structure
- Use FQCN modules (`ansible.builtin.copy`, `community.general.xbps`).
- Prefer dedicated modules over `ansible.builtin.command` and `ansible.builtin.shell`.
- Use `command`/`shell` only when no module exists; explain intent in task name.
- For `command`/`shell`, define `changed_when` and `failed_when` when defaults are unsafe.
- Keep `ansible/site.yml` orchestration-only; place implementation details in roles.
- Keep roles domain-focused (packages, services, profiles, dotfiles).


### YAML formatting and file hygiene
- Start YAML documents with `---`.
- Use 2-space indentation; never tabs.
- Keep key ordering stable and meaningful.
- Quote file modes as strings (`"0644"`, `"0755"`, `"0600"`, `"0700"`).
- Use multiline Jinja for long expressions.
- Avoid trailing whitespace and formatting-only churn.

### Variables, types, and templating
- Use `snake_case` names for variables.
- Use semantically scoped names (`common_packages`, `void_packages_base`, `profile_packages`, `host_packages`).
- Keep booleans as booleans (`true`/`false`), not quoted strings.
- Keep lists/maps as YAML collections, not comma-separated strings.
- Guard optional values with `default([])` and `default({})`.
- Build home-relative paths from `{{ user_home }}` consistently.


### Naming conventions
- Role directory names: lowercase with underscores.
- Task names: imperative, outcome-based, and unique enough for `--start-at-task`.
- Keep inventory group names aligned with related var files.


### Error handling and safety
- Guard OS/profile-specific behavior with `when` clauses.
- Prefer explicit loop inputs over implicit assumptions.
- Do not suppress failures unless there is a clear operational reason.
- Validate risky changes with `--check --diff` before full apply.
- Avoid destructive operations in user homes unless explicitly required.
- Keep tasks non-interactive and automation-safe.

### Dotfiles and shell script style
- Prefer POSIX `sh`; use Bash only when Bash features are required.
- Bash scripts must use `#!/usr/bin/env bash`.
- Quote expansions (`"$var"`) unless intentional word splitting is required.
- Preserve executable bits for copied scripts (`mode: preserve` where appropriate).

## Agent workflow expectations
- Do not modify unrelated files.
- Read inventory, vars, and relevant roles before editing.
- Keep AGENTS and README aligned when workflows/commands change.
- When adding roles or domains, also add validation and targeting guidance.
- Prefer `--limit <host>` validation before broader runs.

## Pre-merge checklist
Run before proposing/finalizing changes:
- `ansible-playbook ansible/site.yml --syntax-check`
- `ansible-playbook ansible/site.yml --check --diff --limit <host>`
- `ansible-inventory --graph`
- If available: `ansible-lint ansible/site.yml` and `yamllint ansible/`
