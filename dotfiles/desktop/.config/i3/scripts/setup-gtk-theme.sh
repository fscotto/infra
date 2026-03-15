#!/bin/sh

THEME="Yaru-blue-dark"
ICONS="Yaru-blue-dark"
CURSOR="Yaru"

FONT_UI="Liberation Sans 10"

mkdir -p "$HOME/.config/gtk-3.0"
mkdir -p "$HOME/.config/gtk-4.0"

cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=$ICONS
gtk-cursor-theme-name=$CURSOR
gtk-font-name=$FONT_UI
gtk-application-prefer-dark-theme=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF

cat > "$HOME/.config/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=$ICONS
gtk-cursor-theme-name=$CURSOR
gtk-font-name=$FONT_UI
gtk-application-prefer-dark-theme=1
EOF

# esporta variabili utili
export GTK_THEME=$THEME
export XCURSOR_THEME=$CURSOR
export XCURSOR_SIZE=24
