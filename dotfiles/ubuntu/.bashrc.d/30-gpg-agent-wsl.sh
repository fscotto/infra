case "$(uname -r 2>/dev/null)" in
  *[Mm]icrosoft*) ;;
  *) return ;;
esac

command -v gpgconf >/dev/null 2>&1 || return

if tty -s; then
  export GPG_TTY="$(tty)"
fi

gpgconf --launch gpg-agent >/dev/null 2>&1
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"

if [ -n "${GPG_TTY-}" ]; then
  gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
fi
