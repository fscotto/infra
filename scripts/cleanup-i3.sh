#!/usr/bin/env sh
# Remove i3 session artifacts: exclusive packages, dotfiles and the emptty
# xsessions entry. Shared resources with sway (dunst, rofi, alacritty,
# xfce4-screenshooter) are left untouched.

set -eu

I3_PACKAGES="
arandr
autorandr
feh
i3
i3blocks
i3blocks-blocklets
i3lock-color
i3status
picom
polybar
scrot
setxkbmap
volumeicon
xclip
xfce4-clipman-plugin
xkbutils
xorg-fonts
xorg-minimal
xss-lock
xdotool
"

I3_DOTFILES="
$HOME/.config/i3
$HOME/.config/i3blocks
$HOME/.config/picom
$HOME/.config/polybar
$HOME/.xinitrc
"

EMPTTY_SESSION=/etc/emptty/xsessions/i3.desktop

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

installed=$(filter_installed "$I3_PACKAGES" | tr '\n' ' ' | sed 's/ *$//')

printf '== i3 cleanup ==\n\n'
printf 'Packages to remove (installed only):\n'
if [ -n "$installed" ]; then
  printf '  %s\n' $installed
else
  printf '  (none)\n'
fi
printf '\nDotfiles to remove:\n'
for d in $I3_DOTFILES; do
  if [ -e "$d" ] || [ -L "$d" ]; then
    printf '  %s\n' "$d"
  fi
done
printf '\nEmptty session entry:\n'
if [ -e "$EMPTTY_SESSION" ]; then
  printf '  %s\n' "$EMPTTY_SESSION"
else
  printf '  (absent)\n'
fi
printf '\nShared (NOT removed): dunst, rofi, alacritty, xfce4-screenshooter and their configs.\n\n'

confirm 'Proceed?' || { printf 'Aborted.\n'; exit 0; }

if [ -n "$installed" ]; then
  # shellcheck disable=SC2086
  sudo xbps-remove -Ry $installed
fi

for d in $I3_DOTFILES; do
  if [ -e "$d" ] || [ -L "$d" ]; then
    rm -rf -- "$d"
  fi
done

if [ -e "$EMPTTY_SESSION" ]; then
  sudo rm -f -- "$EMPTTY_SESSION"
fi

printf '\nDone.\n'
