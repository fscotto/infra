# AGENTS.md

Agent guide for this repository.
Project type: Ansible infrastructure with managed dotfiles.

## Scope and layout
- Entry playbook: `ansible/site.yml`
- Inventory: `ansible/inventory/hosts.yml`
- Group vars: `ansible/inventory/group_vars/*.yml`
- Host vars: `ansible/inventory/host_vars/*.yml`
- Roles: `ansible/roles/*/tasks/main.yml`
- Dotfiles source: `dotfiles/`
- Ansible config: `ansible.cfg`

Current `ansible.cfg` defaults:
- `inventory = ansible/inventory/hosts.yml`
- `roles_path = ansible/roles`
- `host_key_checking = False`
- `retry_files_enabled = False`

## Cursor and Copilot instructions
Checked in this repo and not found:
- `.cursorrules`
- `.cursor/rules/`
- `.github/copilot-instructions.md`

If any of these are added later, treat them as higher-priority local instructions.

## Build, lint, and test commands
There is no compile/build artifact in this repo.
Validation is done with syntax checks, dry-runs, inventory checks, and linting.

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
```

Linting (if installed):
```bash
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

## Single-test equivalents (important)
There is no dedicated test harness (no Molecule/pytest suite).
Use these as targeted single-test workflows:

Syntax-check only:
```bash
ansible-playbook ansible/site.yml --syntax-check
```

Dry-run one host (best single test):
```bash
ansible-playbook ansible/site.yml --limit nymph --check --diff
```

Start from one known task name:
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Copy .bashrc" --check --diff
```

Run one role by task boundary (practical approximation):
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Install Void nonfree repository if needed" --check --diff
```

List hosts targeted by current inventory:
```bash
ansible all --list-hosts
```

Notes:
- `--tags` is preferred for targeted runs once tasks are tagged consistently.
- Today, `site.yml` actively applies `dotfiles_common`, `packages_void`, `services_runit`, and `profile_desktop_i3`.
- Dependencies: Python 3, Ansible, and host access (local or SSH depending on inventory).
- Setup: `python3 -m pip install ansible` (plus optional `ansible-lint yamllint`).

## Code style guidelines

### Core principles
- Keep automation idempotent, declarative, and host-safe.
- Preserve variable layering: `all -> OS -> profile -> host`.
- Keep edits minimal and local; avoid opportunistic refactors.
- Prefer readability over compression in YAML/Jinja.

### Modules, imports, and role structure
- Use FQCN modules (`ansible.builtin.copy`, `community.general.xbps`).
- Prefer modules over `ansible.builtin.shell`/`ansible.builtin.command`.
- If command/shell is necessary, document intent via task name and guards.
- Keep `ansible/site.yml` orchestration-focused; implementation belongs in roles.
- Split large role task files with `import_tasks`/`include_tasks`.
- Keep each role narrow in purpose (packages, services, profile, dotfiles).

### YAML formatting
- Start YAML files with `---`.
- Use 2-space indentation, never tabs.
- Keep key ordering stable and meaningful.
- Quote file modes as strings: `"0644"`, `"0755"`, `"0600"`, `"0700"`.
- Keep long Jinja expressions multiline.
- Avoid trailing whitespace.

### Variables and types
- Use `snake_case` variable names.
- Use semantically scoped names (`common_packages`, `void_packages_base`, `host_packages`).
- Keep booleans as `true`/`false`, not quoted strings.
- Keep lists and dicts as real YAML collections.
- Use `default([])` / `default({})` for optional variables.
- Build paths consistently from `{{ user_home }}` and related vars.
- Put shared defaults in `group_vars/all.yml`; specialize in group/host vars.

### Naming conventions
- Role directories: lowercase with underscores.
- Task names: imperative and outcome-based (`Enable host runit services`).
- Inventory group names and matching var filenames should stay aligned.
- Host var filenames must match hostnames exactly.

### Error handling and safety
- Guard OS/profile-specific steps with `when`.
- Use explicit `loop` inputs and default guards for optional lists.
- For `command`/`shell`, define `changed_when` and `failed_when` when needed.
- Do not suppress failures unless there is a clear operational reason.
- Validate risky changes with `--check --diff` before full apply.
- Avoid destructive file operations in user homes unless explicitly required.
- Avoid touching secrets material; never commit credentials.

### Dotfiles and shell scripts
- Prefer POSIX `sh`; use Bash only when required.
- If Bash is required, use shebang `#!/usr/bin/env bash`.
- Quote expansions (`"$var"`) unless intentional splitting is required.
- Keep scripts non-interactive when invoked by automation.

## Agent expectations
- Do not modify unrelated files.
- Never commit or expose data from `secrets/`.
- Keep `AGENTS.md` and `README.md` in sync with workflow changes.
- When adding new role domains, add tags to support targeted execution.

## Pre-merge checklist
Run before submitting changes:
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
