#!/bin/sh

[ $# -gt 0 ] || set -- i3

[ -r /etc/profile ] && . /etc/profile
[ -r "$HOME/.profile" ] && . "$HOME/.profile"

session_name=${1##*/}

export XDG_CURRENT_DESKTOP="$session_name"
export XDG_SESSION_DESKTOP="$session_name"
export XDG_SESSION_TYPE=x11

exec dbus-run-session sh -eu -c '
  umask 077
  printf "%s\n" "$DBUS_SESSION_BUS_ADDRESS" > "$HOME/.dbus-session-bus-address"
  eval "$(ssh-agent -s)" >/dev/null
  gpgconf --launch gpg-agent
  exec "$@"
' sh "$@"
