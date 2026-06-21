# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Ansible-driven personal infrastructure as code for Void Linux desktops (`ikaros`, `nymph`), Linux workstations (`deadalus-fedora`, `deadalus-wsl`), and an Ubuntu server (`prometheus`). See `AGENTS.md` for topology and `README.md` for full profile descriptions.

## Validation commands

```bash
# Minimum before any change
ansible-playbook ansible/site.yml --syntax-check

# Dry-run per host
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus-fedora --check --diff
ansible-playbook ansible/site.yml --limit deadalus-wsl --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff

# Linting
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/

# Tag-scoped dry-run
ansible-playbook ansible/site.yml --limit ikaros --tags <tag> --check --diff

# Shell scripts
sh -n scripts/bootstrap_mail.sh && shellcheck scripts/bootstrap_mail.sh
```

## Architecture

Configuration is composed in layers: `all → OS → profile → host`. All hosts use `ansible_connection: local`.

`ansible/site.yml` is the sole orchestration entry point — keep it thin. Implementation belongs in roles under `ansible/roles/`.

Variable layering:
- `ansible/inventory/group_vars/` — OS and profile defaults
- `ansible/inventory/host_vars/` — host-specific overrides (never put host overrides in group_vars)

Dotfiles under `dotfiles/` mirror the same layer split: `common/`, `desktop/`, `server/`, `workstation/`, then per-host directories (`ikaros/`, `nymph/`).

## Key conventions

- FQCN for all Ansible modules.
- Prefer declarative modules over `command`/`shell`; when shell is unavoidable, make idempotency explicit.
- YAML: start with `---`, 2-space indent, file modes quoted as `"0644"`, booleans as booleans.
- `no_log: true` on any task that handles secrets.
- Do not restart `emptty` in playbook tasks on active desktop hosts — do it manually via SSH/TTY.

## Void desktop package buckets (keep disjoint)

- `void_packages_base` — system runtime (init, kernel, audio core, networking, firewall, hw daemons)
- `desktop_common_packages` — WM-agnostic GUI infra (GTK theme, polkit, keyring, portals, flatpak, printing)
- `desktop_i3_packages` / `desktop_sway_packages` — session-specific binaries; cross-WM packages used by both (`dunst`, `rofi`, `alacritty`) are intentionally duplicated
- `profile_packages` — cross-distro; do not move desktop-only Void entries into it

Dotfile var split follows the same logic: `desktop_common_dotfiles` (WM-agnostic), `desktop_void_dotfiles` (Void runtime — turnstile services, bash fragments).

## Secrets

- `secrets/vault.yml` and `secrets/vault.local.yml` are loaded conditionally if present.
- `secrets/.vault_pass.gpg` is used automatically if present; falls back to `secrets/.vault_pass`.
- Never print vault values; always use `no_log: true` where secrets flow through tasks.

## AI agent dotfiles

Shared agent instructions live in `dotfiles/common/.config/ai/`. Agent-specific entrypoints reference that path rather than duplicating content. Shared npm packages are in `ai_agents_npm_packages` in `ansible/inventory/group_vars/all.yml`.
