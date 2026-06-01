#!/bin/sh
# Rimuove i3 e relativi dotfiles dall'host corrente.
# Eseguire dopo aver verificato che sway funzioni correttamente.
set -e

HOSTNAME=$(hostname)

# Pacchetti i3-only (dunst e rofi sono condivisi con sway, non rimossi)
sudo xbps-remove -R arandr autorandr feh i3 i3blocks i3blocks-blocklets \
  i3lock-color i3status picom polybar scrot setxkbmap volumeicon xclip \
  xfce4-clipman-plugin xfce4-screenshooter xkbutils xorg-fonts xorg-minimal \
  xss-lock xdotool

# Dotfiles i3-only
rm -rf ~/.config/i3 ~/.config/i3blocks
rm -f  ~/.config/picom/picom.conf
rmdir  --ignore-fail-on-non-empty ~/.config/picom
rm -f  ~/.config/polybar/config.ini ~/.config/polybar/launch.sh
rmdir  --ignore-fail-on-non-empty ~/.config/polybar
rm -f  ~/.xinitrc

# Session file emptty
sudo rm -f /etc/emptty/xsessions/i3.desktop

# Dotfiles host-specifici
case "$HOSTNAME" in
  ikaros|nymph)
    rm -rf ~/.config/autorandr
    ;;
esac
