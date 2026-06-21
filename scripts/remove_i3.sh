#!/bin/sh
# Rimuove i3 (sessione X11) e relativi artefatti dall'host Void corrente:
# pacchetti i3-only, dotfiles, voce emptty e profili autorandr host-specifici.
# Eseguire dopo aver verificato che sway/Hyprland funzionino correttamente.
# I pacchetti condivisi con sway/Hyprland (dunst, rofi, alacritty) NON vengono rimossi.
set -e

HOSTNAME=$(hostname)

# Pacchetti i3-only (X11). dunst/rofi/alacritty sono condivisi e non vengono rimossi.
sudo xbps-remove -R arandr autorandr feh i3 i3blocks i3blocks-blocklets \
  i3lock-color i3status picom polybar scrot setxkbmap volumeicon xclip \
  xfce4-clipman-plugin xfce4-screenshooter xkbutils xorg-fonts xorg-minimal \
  xss-lock xdotool

# Dotfiles i3-only
rm -rf ~/.config/i3 ~/.config/i3blocks
rm -f  ~/.config/picom/picom.conf
rmdir  --ignore-fail-on-non-empty ~/.config/picom 2>/dev/null || true
rm -f  ~/.config/polybar/config.ini ~/.config/polybar/launch.sh
rmdir  --ignore-fail-on-non-empty ~/.config/polybar 2>/dev/null || true
rm -f  ~/.xinitrc

# Session file emptty (X11)
sudo rm -f /etc/emptty/xsessions/i3.desktop

# Dotfiles host-specifici (autorandr = multi-monitor X11)
case "$HOSTNAME" in
  ikaros|nymph)
    rm -rf ~/.config/autorandr
    ;;
esac
