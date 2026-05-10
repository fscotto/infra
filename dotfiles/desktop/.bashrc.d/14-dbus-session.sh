# Validate DBUS_SESSION_BUS_ADDRESS: a stale value (e.g. inherited from a
# dead X session) makes secret-tool, mbsync, msmtp fail with
# "Could not connect: No such file or directory".
# Fall back to ~/.dbus-session-bus-address (written by .xinitrc) or
# /run/user/$UID/bus, mirroring scripts/bootstrap_mail.sh.

_dbus_addr_socket_path() {
  printf '%s' "${1#unix:path=}" | sed 's/,.*//'
}

_dbus_addr_is_live() {
  case "$1" in
    unix:path=*)
      [ -S "$(_dbus_addr_socket_path "$1")" ]
      ;;
    unix:abstract=*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if ! _dbus_addr_is_live "${DBUS_SESSION_BUS_ADDRESS:-}"; then
  unset DBUS_SESSION_BUS_ADDRESS
  if [ -f "$HOME/.dbus-session-bus-address" ]; then
    _saved=$(tr -d '\n' <"$HOME/.dbus-session-bus-address" 2>/dev/null)
    if [ -n "$_saved" ] && _dbus_addr_is_live "$_saved"; then
      export DBUS_SESSION_BUS_ADDRESS="$_saved"
    fi
    unset _saved
  fi
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "/run/user/$(id -u)/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  fi
fi

unset -f _dbus_addr_socket_path _dbus_addr_is_live
