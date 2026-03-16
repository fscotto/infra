# AGENTS.md

Guide for coding agents in this repository.
Project type: Ansible infrastructure + managed dotfiles.

## Repository map
- Entry playbook: `ansible/site.yml`
- Inventory: `ansible/inventory/hosts.yml`
- Group vars: `ansible/inventory/group_vars/*.yml`
- Host vars: `ansible/inventory/host_vars/*.yml`
- Roles: `ansible/roles/*/tasks/main.yml`
- Dotfiles source: `dotfiles/`
- Ansible config: `ansible.cfg`

`ansible.cfg` defaults in use:
- `inventory = ansible/inventory/hosts.yml`
- `roles_path = ansible/roles`
- `host_key_checking = False`
- `retry_files_enabled = False`

## Cursor / Copilot rules status
Checked and not found:
- `.cursorrules`
- `.cursor/rules/`
- `.github/copilot-instructions.md`

If these files are added later, treat them as higher-priority local instructions.

## Dependencies
Required:
- Python 3
- Ansible
- Access to target hosts (local or SSH, depending on inventory)

Install baseline:
```bash
python3 -m pip install ansible
```

Optional quality tools:
```bash
python3 -m pip install ansible-lint yamllint
```

## Build / lint / test commands
There is no compile/build artifact in this repo.
Use syntax checks, dry-runs, and linting as validation.

Main run:
```bash
ansible-playbook ansible/site.yml
```

Run only one host:
```bash
ansible-playbook ansible/site.yml --limit ikaros
```

Dry-run with diff:
```bash
ansible-playbook ansible/site.yml --check --diff
```

Inventory sanity checks:
```bash
ansible-inventory --graph
ansible-inventory --list
```

Linting (if installed):
```bash
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

## Single-test equivalents (important)
No dedicated test harness (pytest/molecule) exists yet.
Use these targeted commands as "single test" workflows.

Syntax-check one playbook:
```bash
ansible-playbook ansible/site.yml --syntax-check
```

Test one host in dry-run mode:
```bash
ansible-playbook ansible/site.yml --limit nymph --check --diff
```

Start at one task:
```bash
ansible-playbook ansible/site.yml --start-at-task "Copy .bashrc" --limit ikaros
```

Run one tag subset (requires tagged tasks):
```bash
ansible-playbook ansible/site.yml --tags dotfiles --limit ikaros
```

## Code style guidelines

### General principles
- Keep changes idempotent and declarative.
- Preserve layering: `common -> OS -> profile -> host`.
- Avoid unrelated refactors; keep edits minimal and local.

### Ansible modules, imports, and structure
- Use FQCN module names (`ansible.builtin.copy`, `community.general.xbps`).
- Prefer modules over raw `shell`/`command`.
- Use `import_tasks`/`include_tasks` when role task files grow.
- Keep `site.yml` orchestration-focused; implementation lives in roles.
- Keep role scope narrow (packages vs services vs dotfiles).

### Formatting
- Start YAML files with `---`.
- Use 2-space indentation; never tabs in YAML.
- Quote modes as strings: `"0644"`, `"0755"`, `"0600"`.
- Keep long Jinja expressions multiline and readable.
- No trailing whitespace.

### Variables and types
- Use `snake_case` variable names.
- Keep names semantically scoped (`common_packages`, `profile_packages`, `host_packages`).
- Use true YAML types: lists for lists, booleans as `true`/`false`.
- Use `default([])` / `default({})` for optional vars.
- Keep paths consistent, usually templated from `{{ user_home }}`.
- Put global defaults in `group_vars/all.yml`; specialize in group/host vars.

### Naming conventions
- Roles: lowercase with underscores.
- Tasks: imperative, explicit outcome (`Install packages on Void Linux`).
- Inventory group and var file names must stay aligned.
- Host var files should match hostnames exactly.

### Error handling and safety
- Guard OS/profile-specific actions with `when`.
- For `command`/`shell`, set `changed_when`/`failed_when` where needed.
- Do not suppress failures without clear justification.
- Validate risky changes with `--check --diff` before real apply.
- Avoid destructive user-file operations unless explicitly required.

### Shell and dotfiles
- Prefer POSIX `sh` unless Bash features are required.
- If Bash is required, use `#!/usr/bin/env bash`.
- Quote expansions (`"$var"`) unless intentional word splitting is required.
- Keep automation-invoked scripts non-interactive.

## Agent operating expectations
- Never commit or expose data from `secrets/`.
- Do not modify unrelated files.
- Keep docs (`README.md`, `AGENTS.md`) current when workflows change.
- If adding new task domains, add tags to improve targeted runs.

## Pre-merge checklist
```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --check --diff --limit <host>
ansible-inventory --graph
```

If lint tools are installed:
```bash
ansible-lint ansible/site.yml
yamllint ansible/
```
