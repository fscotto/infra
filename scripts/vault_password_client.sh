#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
vault_pass_gpg_file="$repo_root/secrets/.vault_pass.gpg"
vault_pass_file="$repo_root/secrets/.vault_pass"

if [ -r "$vault_pass_gpg_file" ]; then
  if ! command -v gpg >/dev/null 2>&1; then
    printf '%s\n' "Encrypted vault password file found at $vault_pass_gpg_file but gpg is not installed." >&2
    exit 1
  fi

  if ! gpg --quiet --batch --decrypt "$vault_pass_gpg_file"; then
    printf '%s\n' "Failed to decrypt vault password file at $vault_pass_gpg_file." >&2
    exit 1
  fi

  exit 0
fi

if [ -r "$vault_pass_file" ]; then
  IFS= read -r password < "$vault_pass_file" || password=''
  printf '%s' "$password"
  exit 0
fi

if [ -t 0 ]; then
  printf 'Vault password: ' >&2
  stty -echo
  IFS= read -r password
  stty echo
  printf '\n' >&2
  printf '%s' "$password"
  exit 0
fi

printf '%s\n' "Vault password files not found at $vault_pass_gpg_file or $vault_pass_file and no interactive TTY is available." >&2
exit 1
