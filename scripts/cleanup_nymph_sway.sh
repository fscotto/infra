#!/usr/bin/env sh

set -eu

PACKAGES="
swayfx
kanshi
grim
grimshot
slurp
wl-clipboard
xdg-desktop-portal-wlr
cliphist
noctalia-shell
"

USER_PATHS="
$HOME/.config/sway
$HOME/.config/kanshi
$HOME/.config/noctalia
$HOME/.local/share/noctalia-plugins
$HOME/.local/bin/start-sway-session
"

SYSTEM_FILES="
/etc/emptty/wayland-sessions/Sway.desktop
/etc/xbps.d/noctalia.conf
"

check_host() {
  if [ "$(hostname)" != "nymph" ]; then
    printf 'Error: questo script è destinato solo a nymph (hostname attuale: %s)\n' "$(hostname)" >&2
    exit 1
  fi
}

remove_packages() {
  printf 'Rimozione pacchetti swayfx+noctalia...\n'
  # shellcheck disable=SC2086
  sudo xbps-remove -Ry $PACKAGES
  printf 'Rimozione dipendenze orfane...\n'
  sudo xbps-remove -o
}

remove_user_configs() {
  printf 'Rimozione configurazioni utente...\n'
  for path in $USER_PATHS; do
    if [ -e "$path" ]; then
      rm -rf "$path"
      printf '  rimosso: %s\n' "$path"
    fi
  done
}

remove_system_files() {
  printf 'Rimozione file di sistema...\n'
  for file in $SYSTEM_FILES; do
    if [ -e "$file" ]; then
      sudo rm -f "$file"
      printf '  rimosso: %s\n' "$file"
    fi
  done
}

main() {
  check_host
  remove_packages
  remove_user_configs
  remove_system_files
  printf 'Cleanup completato.\n'
}

main "$@"
