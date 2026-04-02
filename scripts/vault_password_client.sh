#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
vault_pass_file="$repo_root/secrets/.vault_pass"

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

printf '%s\n' "Vault password file not found at $vault_pass_file and no interactive TTY is available." >&2
exit 1
