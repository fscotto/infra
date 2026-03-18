#!/bin/sh

# dbus session
export XDG_CURRENT_DESKTOP=i3
exec dbus-run-session sh -c "
    umask 077
    printf '%s\n' \"\$DBUS_SESSION_BUS_ADDRESS\" > \"\$HOME/.dbus-session-bus-address\"
    eval \$(ssh-agent -s)
    gpgconf --launch gpg-agent
    exec i3
"
