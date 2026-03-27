# AGENTS.md
Guidance for coding agents working in this repository.
Project type: Ansible-driven infrastructure, workstation/server provisioning, and user dotfiles.
## Repository Map
- Entry playbook: `ansible/site.yml`
- Inventory: `ansible/inventory/hosts.yml`
- Shared vars: `ansible/inventory/group_vars/*.yml`
- Host overrides: `ansible/inventory/host_vars/*.yml`
- Roles: `ansible/roles/*`
- Templates: `ansible/templates/**/*.j2`
- Dotfiles: `dotfiles/`
- Scripts: `scripts/`
- Local secrets area: `secrets/`
## Active Topology
- Void desktops: `ikaros`, `nymph`
- Ubuntu workstation: `deadalus`
- Ubuntu server: `prometheus`
- Most hosts currently use `ansible_connection: local`
## Active Orchestration
`ansible/site.yml` currently applies:
- `all -> dotfiles_common`
- `void -> packages_void, services_runit, profile_desktop_i3`
- `ubuntu_workstation -> packages_ubuntu, services_systemd, profile_workstation_gnome`
- `ubuntu_server -> packages_ubuntu, services_systemd, profile_server`

Roles present but not wired into `ansible/site.yml`:
- `base`
- `dotfiles`
## Local Instruction Files
Checked when this file was updated:
- `.cursorrules`: not present
- `.cursor/rules/`: not present
- `.github/copilot-instructions.md`: not present
If any appear later, treat them as higher-priority repo-local instructions.
## Working Principles
- Preserve the layering: `all -> OS -> profile -> host`
- Prefer minimal, targeted edits over cleanup refactors
- Preserve idempotency and reproducibility
- Validate on one limited host before broad rollout
- Treat `secrets/` as sensitive and never print secret values
- Avoid editing vendored code under `dotfiles/common/.tmux/plugins/` unless explicitly asked
## Build, Lint, And Test Commands
There is no compile/build pipeline. Confidence comes from syntax checks, dry runs, linting, and targeted script validation.
Install tooling if needed:
```bash
python3 -m pip install ansible ansible-lint yamllint
ansible-galaxy collection install community.general
```
Core validation:
```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit deadalus --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
```
Linting and script checks:
```bash
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
sh -n scripts/bootstrap_mail.sh
shellcheck scripts/bootstrap_mail.sh
```
Useful execution commands:
```bash
ansible-playbook ansible/site.yml
ansible-playbook ansible/site.yml --limit deadalus
scripts/bootstrap_mail.sh
```
## Single-Test Equivalents
There is no pytest, Molecule, or unit-test suite. Use the narrowest command matching the changed area.
- Single playbook syntax test: `ansible-playbook ansible/site.yml --syntax-check`
- Single host check: `ansible-playbook ansible/site.yml --limit <host> --check --diff`
- Single task restart point: `ansible-playbook ansible/site.yml --limit <host> --start-at-task "<task name>" --check --diff`
- Single script syntax test: `sh -n scripts/bootstrap_mail.sh`
- Single script lint: `shellcheck scripts/bootstrap_mail.sh`
When changing one area, prefer:
- vars or inventory: one limited host dry run
- one role: one limited host dry run, plus `ansible-lint ansible/roles/<role>` if available
- one template: one limited host dry run with `--diff`
- one script: `sh -n` and `shellcheck` on that script
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
### Imports, Modules, And Task Structure
- Use FQCN module names such as `ansible.builtin.copy` and `community.general.ufw`
- Prefer dedicated modules over `ansible.builtin.command` or `ansible.builtin.shell`
- Use `command` only when no module fits; use `shell` only for shell features
- When using `command` or `shell`, set `changed_when` and `failed_when` when defaults are misleading
- Keep task names imperative, descriptive, and stable enough for `--start-at-task`
- Tag tasks consistently with existing families such as `packages`, `services`, `dotfiles`, `gnome`, and `dotfiles:*`
- Prefer `loop` with `loop_control.label` for multi-item tasks
### Variables, Types, And Naming
- Use `snake_case` for vars, facts, and registered values
- Follow existing families such as `common_packages`, `ubuntu_packages_base`, `profile_packages`, `host_packages`, `workstation_dotfiles`, and `host_enabled_services`
- Keep booleans as booleans, not quoted strings
- Keep structured values as YAML lists/maps, not comma-separated strings
- Guard optional lists with `default([])`, mappings with `default({})`, and strings with `default('')`
- Build managed-user paths from `{{ user_home }}`
- Put host-specific overrides in `host_vars`, not shared `group_vars`
### Templates And Dotfiles
- Keep secrets parameterized through vars; never hardcode them in templates
- Preserve destination paths and permissions unless the task requires a change
- For workstation-only files, prefer `group_vars/workstation.yml` and the workstation role
- For server-only changes, keep them out of workstation profiles
- Do not modify Git templates unless the task explicitly concerns Git behavior
### Area-Specific Guidance
- `ansible/site.yml`: orchestration only; keep it small
- `ansible/inventory/group_vars/*.yml`: shared defaults by scope
- `ansible/inventory/host_vars/*.yml`: host-specific deltas only
- `ansible/roles/*/tasks/main.yml`: implementation details and ordered steps
- `ansible/templates/**/*.j2`: parameterized config files
- `dotfiles/`: deployed user config and session scripts
- `scripts/`: local helper scripts that should remain safe for manual execution
### Error Handling And Safety
- Fail early with `ansible.builtin.fail` when prerequisites are missing
- Guard OS-specific, DE-specific, and host-specific behavior with `when`
- Use `no_log: true` for passwords, tokens, and secret-bearing command results
- Use `failed_when: false` only for intentional probes
- Keep tasks non-interactive unless explicitly user-driven
- Avoid destructive changes in user homes unless clearly required
- For firewall changes, allow required access before enabling the firewall
### Shell Script Style
- Prefer POSIX `sh` for simple scripts; use Bash only when needed
- Use `set -eu` in POSIX shell scripts unless there is a reason not to
- Quote variable expansions unless intentional splitting is required
- Use helper functions for repeated checks and cleanup
## Validation Expectations Before Finishing
Run the narrowest useful checks for the files you changed.
Default minimum:
```bash
ansible-playbook ansible/site.yml --syntax-check
```
Preferred for vars, templates, roles, packages, services, PAM, GNOME, mail, firewall, or dotfile changes:
```bash
ansible-playbook ansible/site.yml --limit <host> --check --diff
```
If you touched `scripts/bootstrap_mail.sh`, also run:
```bash
sh -n scripts/bootstrap_mail.sh
shellcheck scripts/bootstrap_mail.sh
```
## Agent Workflow Expectations
- Read the relevant inventory, vars, role tasks, templates, and dotfiles before editing
- Do not revert unrelated worktree changes made by the user
- Keep `README.md` and `AGENTS.md` aligned when workflows materially change
- If you add a new operational area, also add the validation command agents should run
- Prefer host-limited validation first, especially `deadalus` for workstation work and `prometheus` for server work
- Call out checks you could not run and any follow-up verification needed
