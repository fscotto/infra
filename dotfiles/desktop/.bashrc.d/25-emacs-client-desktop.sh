if command -v emacsclient >/dev/null 2>&1; then
  ec() {
    emacsclient -c -n "$@" || {
      printf '%s\n' "Emacs server is not available. Log into a graphical session and ensure the user 'emacs' service is running." >&2
      return 1
    }
  }

  et() {
    emacsclient -t "$@" || {
      printf '%s\n' "Emacs server is not available. Ensure the user 'emacs' service is running in your graphical session." >&2
      return 1
    }
  }
fi
