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
As of now, these files are not present:
- `.cursorrules`
- `.cursor/rules/`
- `.github/copilot-instructions.md`

If any appear later, treat them as higher-priority local instructions.

## Build, lint, and test commands
There is no compile/build artifact in this repo.
Validation is performed with syntax checks, dry-runs, inventory checks, and linting.

Main apply run:
```bash
ansible-playbook ansible/site.yml
```

Dry-run with diff:
```bash
ansible-playbook ansible/site.yml --check --diff
```

Run one host:
```bash
ansible-playbook ansible/site.yml --limit ikaros
```

Inventory sanity checks:
```bash
ansible-inventory --graph
ansible-inventory --list
ansible all --list-hosts
```

Linting (if installed):
```bash
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

## Single-test equivalents (important)
There is no Molecule/pytest test suite in this repo.
Use these targeted checks as "single test" workflows.

Syntax-only check:
```bash
ansible-playbook ansible/site.yml --syntax-check
```

Best single-host safety test:
```bash
ansible-playbook ansible/site.yml --limit nymph --check --diff
```

Start from one known task:
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Copy common dotfiles" --check --diff
```

Role-boundary approximation:
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Install Void nonfree repository if needed" --check --diff
```

Notes:
- Current active stack in `site.yml`: `dotfiles_common`, `packages_void`, `services_runit`, `profile_desktop_i3`.
- Use `--tags` for targeted runs when tags are available.
- Minimum dependencies: Python 3, Ansible, host access (local or SSH).
- Setup example: `python3 -m pip install ansible`.

## Code style guidelines

### Core principles
- Prefer idempotent, declarative, host-safe automation.
- Preserve layering: `all -> OS -> profile -> host`.
- Keep edits minimal and scoped to user intent.
- Avoid speculative refactors unrelated to the requested change.
- Optimize for readability over clever Jinja/YAML compression.

### Modules, imports, and task structure
- Use FQCN modules (`ansible.builtin.copy`, `community.general.xbps`).
- Prefer modules over `ansible.builtin.command`/`ansible.builtin.shell`.
- Use `command`/`shell` only when no module fits; explain intent in task name.
- When using `command`/`shell`, set `changed_when` and `failed_when` as needed.
- Keep `ansible/site.yml` orchestration-only; implementation belongs in roles.
- Keep roles focused by domain (packages, services, profile, dotfiles).
- Split large task files with `import_tasks`/`include_tasks`.

### YAML formatting and file hygiene
- Start YAML documents with `---`.
- Use 2-space indentation; never tabs.
- Keep key ordering stable and meaningful.
- Quote file modes as strings (`"0644"`, `"0755"`, `"0600"`, `"0700"`).
- Use multiline Jinja for long expressions.
- Avoid trailing whitespace and noisy reformatting.

### Variables, types, and templating
- Use `snake_case` variables.
- Use semantically scoped names (`common_packages`, `void_packages_base`, `host_packages`).
- Keep booleans as real booleans (`true`/`false`), not quoted strings.
- Keep lists/maps as YAML collections, not comma-separated strings.
- Use guards for optional values: `default([])`, `default({})`.
- Build home-relative paths from `{{ user_home }}` consistently.
- Put shared defaults in `group_vars/all.yml`; specialize in group/host vars.

### Naming conventions
- Role directory names: lowercase with underscores.
- Task names: imperative and outcome-based.
- Keep inventory group names and var file names aligned.
- Host var filenames must match hostnames exactly.

### Error handling and safety
- Guard OS/profile-specific behavior with `when`.
- Prefer explicit `loop` inputs; avoid implicit assumptions.
- Do not suppress failures without a clear operational reason.
- Validate risky changes with `--check --diff` before full apply.
- Avoid destructive operations in user homes unless explicitly required.
- Never commit credentials or contents from `secrets/`.

### Dotfiles and shell script style
- Prefer POSIX `sh`; use Bash only when required.
- Bash scripts should use `#!/usr/bin/env bash`.
- Quote expansions (`"$var"`) unless intentional splitting is required.
- Keep scripts non-interactive when run by automation.
- Preserve executable bits on scripts copied with `mode: preserve`.

## Agent workflow expectations
- Do not modify unrelated files.
- Verify assumptions by reading inventory, vars, and active roles before editing.
- Keep AGENTS and README aligned when workflow or commands change.
- When adding new domains/roles, also add tagging and validation guidance.

## Pre-merge checklist
Run before proposing or finalizing changes:
```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --check --diff --limit <host>
ansible-inventory --graph
```

If lint tooling is installed:
```bash
ansible-lint ansible/site.yml
yamllint ansible/
```
