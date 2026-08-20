if command -v emacsclient >/dev/null 2>&1; then
  ec() {
    emacsclient -c -n "$@" || {
      printf '%s\n' "Emacs server is not available. Start Emacs or run M-x server-start." >&2
      return 1
    }
  }

  et() {
    emacsclient -t "$@" || {
      printf '%s\n' "Emacs server is not available. Start Emacs or run M-x server-start." >&2
      return 1
    }
  }
fi
