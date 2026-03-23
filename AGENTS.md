# AGENTS.md
Guidance for agentic coding tools working in this repository.
Project type: Ansible-based infrastructure plus managed dotfiles.

## Repository snapshot
- Entry playbook: `ansible/site.yml`
- Ansible config: `ansible.cfg`
- Inventory: `ansible/inventory/hosts.yml`
- Group vars: `ansible/inventory/group_vars/*.yml`
- Host vars: `ansible/inventory/host_vars/*.yml`
- Active roles: `dotfiles_common`, `packages_void`, `services_runit`, `profile_desktop_i3`, `packages_ubuntu`, `services_systemd`, `profile_workstation_gnome`
- Roles present but not currently wired into `ansible/site.yml`: `base`, `dotfiles`, `profile_server`
- Dotfiles source of truth: `dotfiles/`
- Utility scripts: `scripts/`
- Sensitive local material/examples: `secrets/`

## Local instruction files
Checked in this repository when this file was written:
- `.cursorrules`: not present
- `.cursor/rules/`: not present
- `.github/copilot-instructions.md`: not present
If any of these files appear later, treat them as higher-priority local instructions.

## Working assumptions
- Favor idempotent, host-safe changes over cleverness.
- Preserve the intended layering: `all -> OS -> profile -> host`.
- Validate on one host before broad rollout.
- Prefer minimal, targeted edits over cleanup refactors.
- Treat `secrets/` as sensitive and avoid exposing secret values.
- The repo contains both first-party dotfiles and vendored third-party plugin code.

## Current orchestration model
`ansible/site.yml` currently applies:
- `all -> dotfiles_common`
- `void -> packages_void, services_runit, profile_desktop_i3`
- `ubuntu_workstation -> packages_ubuntu, services_systemd, profile_workstation_gnome`

Ubuntu server inventory and role scaffolding still exist, but the server path is not yet orchestrated by the main playbook.

## Build, lint, and test commands
There is no compile/build step. Validation is based on Ansible syntax checks, inventory inspection, dry-runs, and linting.

Install base tooling if needed:
```bash
python3 -m pip install ansible
ansible-galaxy collection install community.general
```

Core commands:
```bash
ansible-playbook ansible/site.yml
ansible-playbook ansible/site.yml --check --diff
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros
ansible-playbook ansible/site.yml --limit nymph
ansible-playbook ansible/site.yml --limit deadalus
ansible-playbook ansible/site.yml --limit ubuntu_workstation
ansible-inventory --graph
ansible-inventory --host ikaros
ansible-inventory --host deadalus
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

Best default host-scoped dry-run:
```bash
ansible-playbook ansible/site.yml --limit ikaros --check --diff
```

Validate one host's resolved inventory only:
```bash
ansible-inventory --host ikaros
```

Validate a narrow Ansible change starting from one task:
```bash
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Copy common dotfiles" --check --diff
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Install Void nonfree repository if needed" --check --diff
ansible-playbook ansible/site.yml --limit ikaros --start-at-task "Copy desktop dotfiles" --check --diff
```

Validate the standalone mail bootstrap script only:
```bash
sh -n scripts/bootstrap_mail.sh
shellcheck scripts/bootstrap_mail.sh
```

Testing notes:
- Prefer `--limit` aggressively to avoid accidental multi-host rollout.
- Prefer `--check --diff` before package, service, PAM, bootloader, or session changes.
- Keep task names stable and unique enough to support `--start-at-task`.
- If you change only vars, inventory inspection may be the quickest useful check.

## Code style guidelines
### General principles
- Keep orchestration in playbooks and implementation details in roles.
- Prefer declarative modules over imperative commands.
- Avoid unrelated refactors while solving a targeted task.
- Preserve idempotency and make state transitions explicit.
- Keep changes readable for humans reviewing YAML and shell.

### Ansible modules and task structure
- Use FQCN module names such as `ansible.builtin.copy` and `community.general.xbps`.
- Prefer purpose-built modules over `ansible.builtin.command` or `ansible.builtin.shell`.
- Use `command` only when no good module exists.
- Use `shell` only when shell features are genuinely required.
- When using `command` or `shell`, set `changed_when` and `failed_when` when defaults are misleading.
- Keep task names imperative, outcome-based, and unique enough for `--start-at-task`.
- Use `block` when a sequence of tasks shares one condition or operational purpose.
- Prefer `loop` with clear `loop_control.label` for user-facing collections.

### YAML formatting
- Start YAML files with `---`.
- Use 2-space indentation and never tabs.
- Keep keys, lists, and maps in stable, readable order.
- Quote file modes as strings: `"0644"`, `"0755"`, `"0600"`, `"0700"`.
- Prefer multiline Jinja when a one-line expression becomes hard to read.
- Avoid formatting-only churn in untouched sections.

### Variables, types, and templating
- Use `snake_case` consistently for variables and facts.
- Follow existing naming families such as `common_packages`, `profile_packages`, `host_packages`, and `host_dotfiles`.
- Keep booleans as booleans, not quoted strings.
- Keep structured data as YAML collections, not comma-separated strings.
- Guard optional collections and maps with `default([])` and `default({})`.
- Guard optional strings with `default('')`.
- Build user paths from `{{ user_home }}` instead of hardcoding home directories.
- Prefer explicit derived facts with `set_fact` only when reuse improves clarity.

### Naming conventions
- Role names stay lowercase with underscores.
- Inventory groups and matching var files should stay semantically aligned.
- Host-specific overrides belong in `host_vars`, not shared group files.
- New variables should fit existing naming patterns instead of introducing one-off aliases.

### Error handling and safety
- Guard OS-specific or profile-specific behavior with `when` clauses.
- Prefer explicit inputs over assumptions about host state.
- Do not suppress failures without a clear operational reason.
- Use `failed_when: false` only for intentional probes or best-effort detection.
- Use `no_log: true` for secrets, tokens, passwords, and sensitive command results.
- Keep tasks non-interactive and automation-safe.
- Avoid destructive operations in user homes unless the request clearly requires them.
- Fail early with `ansible.builtin.fail` when prerequisites such as architecture or required metadata are missing.

### Shell and script conventions
- Prefer POSIX `sh` for simple login/session/bootstrap scripts.
- Use Bash only when Bash features are actually required; then use `#!/usr/bin/env bash`.
- Quote variable expansions unless intentional word splitting is required.
- Keep helper functions small and focused.
- Exit with clear errors when required commands or files are missing.
- Preserve executable bits for deployed scripts where appropriate.

### Imports and external code
- There are no Python import conventions to optimize for here; most changes are YAML, Jinja, and shell.
- If you add Python later, follow standard-library, third-party, local import grouping and keep modules small.
- Treat `dotfiles/common/.tmux/plugins/` as vendored upstream code unless the task explicitly targets it.
- Prefer changing first-party wrapper/config files before patching vendored plugin internals.

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

Useful supporting checks:
```bash
ansible-inventory --graph
ansible-inventory --host <host>
ansible-lint ansible/site.yml
yamllint ansible/
sh -n scripts/bootstrap_mail.sh
```

## Agent workflow expectations
- Read the relevant inventory, vars, role tasks, templates, and deployed dotfiles before editing.
- Do not change unrelated files to "clean things up".
- Keep `README.md` and `AGENTS.md` aligned when workflows materially change.
- If you add a new operational area, also add the validation command agents should run.
- Prefer host-limited validation before broad apply.
- Call out any verification you could not run.
