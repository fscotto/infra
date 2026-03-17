#!/usr/bin/env sh

set -eu

printf "Proton Bridge password: "
stty -echo
IFS= read -r proton_bridge_password
stty echo
printf "\n"

if [ -z "$proton_bridge_password" ]; then
  printf "Error: empty password, nothing stored.\n" >&2
  exit 1
fi

printf "%s" "$proton_bridge_password" \
  | secret-tool store --label="ProtonMail Bridge" protonmail-bridge protonmail

printf "ProtonMail Bridge secret updated in GNOME Keyring.\n"
