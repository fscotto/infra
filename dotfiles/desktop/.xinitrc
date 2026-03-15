#!/bin/sh

# dbus session
export XDG_CURRENT_DESKTOP=i3
exec dbus-run-session sh -c "
    eval \$(ssh-agent -s)
    gpgconf --launch gpg-agent
    exec i3
"
