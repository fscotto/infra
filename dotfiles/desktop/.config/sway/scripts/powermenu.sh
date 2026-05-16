#!/bin/sh

choice="$(printf "⏻  Shutdown\n  Reboot\n  Logout\n  Lock\n⏾  Suspend" \
| rofi -dmenu \
-i \
-p "Power" \
-theme ~/.config/rofi/config.rasi \
-theme-str 'window { width: 20%; location: center; anchor: center; } listview { columns: 1; spacing: 6px; }')"

[ -z "$choice" ] && exit 0

case "$choice" in
    *Lock)
        ~/.config/sway/scripts/lockscreen
        ;;
    *Logout)
        swaymsg exit
        ;;
    *Suspend)
        ~/.config/sway/scripts/lockscreen
        loginctl suspend
        ;;
    *Reboot)
        loginctl reboot
        ;;
    *Shutdown)
        loginctl poweroff
        ;;
esac
