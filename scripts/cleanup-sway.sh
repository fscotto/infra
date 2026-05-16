#!/usr/bin/env sh
# Remove sway session artifacts: exclusive packages, dotfiles, runtime state
# and the emptty wayland-sessions entry. Shared resources with i3 (dunst,
# rofi, alacritty, xfce4-screenshooter) are left untouched.

set -eu

SWAY_PACKAGES="
cliphist
kanshi
swayfx
swaybg
swayidle
swaylock
SwayOSD
Waybar
wl-clipboard
xdg-desktop-portal-wlr
xorg-server-xwayland
"

SWAY_DOTFILES="
$HOME/.config/sway
$HOME/.config/waybar
$HOME/.cache/cliphist
"

SWAY_SYSTEM_FILES="
/etc/emptty/wayland-sessions/sway.desktop
/usr/local/bin/start-sway
"

confirm() {
  printf '%s [y/N] ' "$1"
  read -r answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

filter_installed() {
  for p in $1; do
    if xbps-query -p pkgver "$p" >/dev/null 2>&1; then
      printf '%s\n' "$p"
    fi
  done
}

if ! command -v xbps-remove >/dev/null 2>&1; then
  printf 'Error: xbps-remove not found (not a Void host?)\n' >&2
  exit 1
fi

installed=$(filter_installed "$SWAY_PACKAGES" | tr '\n' ' ' | sed 's/ *$//')

printf '== sway cleanup ==\n\n'
printf 'Packages to remove (installed only):\n'
if [ -n "$installed" ]; then
  printf '  %s\n' $installed
else
  printf '  (none)\n'
fi
printf '\nDotfiles / state to remove:\n'
for d in $SWAY_DOTFILES; do
  if [ -e "$d" ] || [ -L "$d" ]; then
    printf '  %s\n' "$d"
  fi
done
printf '\nSystem files to remove:\n'
for f in $SWAY_SYSTEM_FILES; do
  if [ -e "$f" ] || [ -L "$f" ]; then
    printf '  %s\n' "$f"
  fi
done
printf '\nShared (NOT removed): dunst, rofi, alacritty, xfce4-screenshooter and their configs.\n\n'

confirm 'Proceed?' || { printf 'Aborted.\n'; exit 0; }

if [ -n "$installed" ]; then
  # shellcheck disable=SC2086
  sudo xbps-remove -Ry $installed
fi

for d in $SWAY_DOTFILES; do
  if [ -e "$d" ] || [ -L "$d" ]; then
    rm -rf -- "$d"
  fi
done

for f in $SWAY_SYSTEM_FILES; do
  if [ -e "$f" ] || [ -L "$f" ]; then
    sudo rm -f -- "$f"
  fi
done

printf '\nDone.\n'
