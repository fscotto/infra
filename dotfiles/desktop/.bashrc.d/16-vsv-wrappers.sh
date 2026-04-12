vsvu() {
  command vsv -d "$HOME/.local/runit/current" "$@"
}

vsvs() {
  command vsv -d "$HOME/.config/service" "$@"
}

vsvc() {
  local user_svdir session_svdir cmd service user_path session_path

  user_svdir="$HOME/.local/runit/current"
  session_svdir="$HOME/.config/service"

  if ! command -v vsv >/dev/null 2>&1; then
    printf '%s\n' "vsv is not installed or not in PATH" >&2
    return 127
  fi

  if [ "$#" -eq 0 ] || { [ "$1" = "status" ] && [ "$#" -eq 1 ]; }; then
    printf '%s\n' "== Always-on services =="
    if [ -d "$user_svdir" ]; then
      command vsv -d "$user_svdir" status
    else
      printf '%s\n' "missing: $user_svdir" >&2
    fi

    printf '\n%s\n' "== Session services =="
    if [ -d "$session_svdir" ]; then
      command vsv -d "$session_svdir" status
    else
      printf '%s\n' "missing: $session_svdir" >&2
    fi
    return
  fi

  cmd="$1"
  service="$2"

  if [ -z "$service" ]; then
    printf '%s\n' "usage: vsvc [status [service] | <command> <service>]" >&2
    return 2
  fi

  user_path="$user_svdir/$service"
  session_path="$session_svdir/$service"

  if [ -e "$user_path" ] && [ -e "$session_path" ]; then
    printf '%s\n' "service '$service' exists in both trees; use vsvu or vsvs explicitly" >&2
    return 2
  fi

  if [ -e "$user_path" ]; then
    command vsv -d "$user_svdir" "$@"
    return
  fi

  if [ -e "$session_path" ]; then
    command vsv -d "$session_svdir" "$@"
    return
  fi

  printf '%s\n' "service '$service' not found in $user_svdir or $session_svdir" >&2
  return 1
}
