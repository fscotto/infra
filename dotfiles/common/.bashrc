# =========================
# Portable Bash config
# Target: Void Linux + FreeBSD
# =========================

# Exit if not interactive
[[ $- != *i* ]] && return

# --- environment detection
case "$(uname -s)" in
  Linux)   PLATFORM="linux" ;;
  FreeBSD) PLATFORM="freebsd" ;;
  *)       PLATFORM="other" ;;
esac

export PLATFORM

# --- history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
HISTIGNORE='ls:ll:la:l:pwd:exit:clear:history'
HISTTIMEFORMAT=
shopt -s histappend
shopt -s checkwinsize

__history_sync() {
  history -a
  history -c
  history -r
}

# --- shell options
set -o emacs
shopt -s cmdhist

# --- PATH
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"
export PATH

if [ -d "$HOME/.bashrc.d" ]; then
  for bashrc_file in "$HOME"/.bashrc.d/*.sh; do
    [ -r "$bashrc_file" ] || continue
    . "$bashrc_file"
  done
fi

# =========================
# Aliases (portable)
# =========================

if ls --color=auto >/dev/null 2>&1; then
  alias ls='ls --color=auto'
else
  alias ls='ls -G'
fi

alias l='ls'
alias ll='ls -lh'
alias la='ls -lah'

if grep --color=auto "" /dev/null >/dev/null 2>&1; then
  alias grep='grep --color=auto'
fi

alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Git
alias g='git'
alias ga='git add'
alias gb='git branch'
alias gc='git commit'
alias gca='git commit -a'
alias gco='git checkout'
alias gd='git diff'
alias gl='git pull'
alias gp='git push'
alias gs='git status -sb'
alias glog='git log --oneline --decorate --graph -20'

# =========================
# Git prompt helpers
# =========================

__git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  command git symbolic-ref --quiet --short HEAD 2>/dev/null && return
  command git rev-parse --short HEAD 2>/dev/null && return
  return 1
}

__git_flags() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  local flags=""
  git diff --no-ext-diff --quiet --exit-code 2>/dev/null || flags="${flags}*"
  git diff --cached --no-ext-diff --quiet --exit-code 2>/dev/null || flags="${flags}+"
  [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ] && flags="${flags}?"

  printf '%s' "$flags"
}

# =========================
# Colors
# =========================

if [ -t 1 ]; then
  C_RESET='\[\033[0m\]'
  C_USER='\[\033[1;97m\]'
  C_HOST='\[\033[38;5;250m\]'
  C_PATH='\[\033[1;96m\]'
  C_GIT='\[\033[38;5;197m\]'
  C_GIT_FLAG='\[\033[38;5;204m\]'
  C_VENV='\[\033[38;5;177m\]'
  C_CONT='\[\033[38;5;208m\]'
  C_OK='\[\033[38;5;46m\]'
  C_ERR='\[\033[38;5;196m\]'
  C_DIM='\[\033[38;5;240m\]'
else
  C_RESET=''
  C_USER=''
  C_HOST=''
  C_PATH=''
  C_GIT=''
  C_GIT_FLAG=''
  C_VENV=''
  C_CONT=''
  C_OK=''
  C_ERR=''
  C_DIM=''
fi

# =========================
# Prompt helpers
# =========================

__prompt_git() {
  local branch flags

  branch="$(__git_branch)" || return 0
  flags="$(__git_flags)"

  if [ -n "$flags" ]; then
    printf ' %s<%s%s:%s%s>%s' \
      "$C_GIT" "$branch" "$C_DIM" "$C_GIT_FLAG" "$flags" "$C_RESET"
  else
    printf ' %s<%s>%s' "$C_GIT" "$branch" "$C_RESET"
  fi
}

__prompt_venv() {
  [ -n "${VIRTUAL_ENV-}" ] || return 0
  printf ' %s(%s)%s' "$C_VENV" "${VIRTUAL_ENV##*/}" "$C_RESET"
}

__prompt_container() {
  local marker=""

  if [ -f /run/.containerenv ]; then
    marker="ctr"
  elif [ -f /.dockerenv ]; then
    marker="docker"
  elif [ -n "${container-}" ]; then
    marker="$container"
  elif [ -n "${debian_chroot-}" ]; then
    marker="$debian_chroot"
  fi

  [ -n "$marker" ] || return 0
  printf ' %s[%s]%s' "$C_CONT" "$marker" "$C_RESET"
}

# =========================
# Prompt
# =========================

__set_prompt() {
  local last_status="$1"
  local host_part symbol status_color

  if [ -n "${SSH_CONNECTION-}" ] || [ -n "${SSH_CLIENT-}" ]; then
    host_part="${C_USER}\u${C_DIM}@${C_HOST}\h${C_RESET}"
  else
    host_part="${C_USER}\u${C_RESET}"
  fi

  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    symbol="#"
  else
    symbol="›"
  fi

  if [ "$last_status" -eq 0 ]; then
    status_color="${C_OK}"
  else
    status_color="${C_ERR}"
  fi

  PS1="${host_part}${C_DIM}:${C_RESET}${C_PATH}\w${C_RESET}$(__prompt_venv)$(__prompt_container)$(__prompt_git) ${status_color}${symbol}${C_RESET} "
}

__prompt_command() {
  local last_status=$?
  __history_sync
  __set_prompt "$last_status"
}

PROMPT_COMMAND="__prompt_command"

# =========================
# Readline / history search
# =========================

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

bind '"\e[1;5C": forward-word'
bind '"\e[1;5D": backward-word'
bind '"\e[5C": forward-word'
bind '"\e[5D": backward-word'

# =========================
# fzf: Ptyxis Linux Minimal
# =========================

if command -v fzf >/dev/null 2>&1; then
  FZF_PTYXIS_LINUX_OPTS="
    --layout=reverse
    --border=rounded
    --height=40%
    --info=inline
    --prompt='› '
    --pointer='›'
    --marker='✓'
    --separator='─'
    --scrollbar='│'
    --color=bg:#000000,bg+:#000000,gutter:#000000
    --color=fg:#d7d7d7,fg+:#ffffff,hl:#55ff55,hl+:#55ff55
    --color=prompt:#55ff55,pointer:#5555ff,marker:#ffff55,spinner:#5555ff
    --color=info:#808080,header:#808080,border:#303030
  "
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }$FZF_PTYXIS_LINUX_OPTS"

# =========================
# fzf history on Ctrl-r
# =========================

  __fzf_history() {
    local selected history_data

    if command -v tac >/dev/null 2>&1; then
      history_data="$(
        builtin history \
          | sed 's/^[[:space:]]*[0-9][0-9]*[[:space:]]*//' \
          | awk '!seen[$0]++' \
          | awk 'NF' \
          | tac
      )"
    else
      history_data="$(
        builtin history \
          | sed 's/^[[:space:]]*[0-9][0-9]*[[:space:]]*//' \
          | awk '!seen[$0]++' \
          | awk 'NF' \
          | tail -r
      )"
    fi

    selected="$(printf '%s\n' "$history_data" | fzf --prompt='history> ')" || return

    READLINE_LINE=$selected
    READLINE_POINT=${#READLINE_LINE}
  }

  bind -x '"\C-r":__fzf_history'
fi

# =========================
# Completion
# =========================

for bc in \
  /usr/share/bash-completion/bash_completion \
  /usr/local/share/bash-completion/bash_completion \
  /etc/bash_completion
do
  if [ -r "$bc" ]; then
    . "$bc"
    break
  fi
done

# =========================
# zoxide - smarter cd
# =========================

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

# =========================
# Portable helpers
# =========================

mkcd() {
  [ $# -eq 1 ] || return 1
  mkdir -p -- "$1" && cd -- "$1" || return
}

__cd_resolve_case_insensitive() {
  local target="$1"
  local base rest component entry name
  local -a parts matches

  if [[ "$target" == /* ]]; then
    base="/"
    rest=${target#/}
  else
    base="."
    rest=$target
  fi

  IFS='/' read -r -a parts <<< "$rest"

  for component in "${parts[@]}"; do
    [ -n "$component" ] || continue

    case "$component" in
      .|..)
        base="$base/$component"
        continue
        ;;
    esac

    matches=()

    if [[ "$component" == .* ]]; then
      for entry in "$base"/.*; do
        [ -d "$entry" ] || continue
        name=${entry##*/}
        case "$name" in
          .|..) continue ;;
        esac
        [[ ${name,,} == ${component,,} ]] && matches+=("$entry")
      done
    else
      for entry in "$base"/*; do
        [ -d "$entry" ] || continue
        name=${entry##*/}
        [[ ${name,,} == ${component,,} ]] && matches+=("$entry")
      done
    fi

    case ${#matches[@]} in
      0)
        return 1
        ;;
      1)
        base=${matches[0]}
        ;;
      *)
        printf 'cd: ambiguous case-insensitive match for %s\n' "$target" >&2
        printf '%s\n' "${matches[@]}" >&2
        return 2
        ;;
    esac
  done

  printf '%s\n' "$base"
}

cd() {
  local resolved status

  if builtin cd "$@" 2>/dev/null; then
    return 0
  fi
  status=$?

  if [ $# -ne 1 ]; then
    builtin cd "$@"
    return $?
  fi

  case "$1" in
    ''|-|-*)
      builtin cd "$@"
      return $?
      ;;
  esac

  resolved=$(__cd_resolve_case_insensitive "$1")
  status=$?

  case $status in
    0)
      builtin cd -- "$resolved"
      ;;
    2)
      return 1
      ;;
    *)
      builtin cd "$@"
      ;;
  esac
}

extract() {
  [ $# -eq 1 ] || {
    printf 'usage: extract <archive>\n' >&2
    return 1
  }

  [ -f "$1" ] || {
    printf 'extract: file not found: %s\n' "$1" >&2
    return 1
  }

  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz|*.txz)   tar xJf "$1" ;;
    *.tar)            tar xf "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.gz)             gunzip "$1" ;;
    *.xz)             unxz "$1" ;;
    *.zip)            unzip "$1" ;;
    *.7z)             7z x "$1" ;;
    *) printf 'extract: unsupported archive: %s\n' "$1" >&2; return 1 ;;
  esac
}

# =========================
# OS-specific small touches
# =========================

if [ "$PLATFORM" = "freebsd" ]; then
  alias df='df -h'
  alias du='du -h'
elif [ "$PLATFORM" = "linux" ]; then
  alias df='df -h'
  alias du='du -h'
fi

[ -r "$HOME/.bashrc.aliases" ] && . "$HOME/.bashrc.aliases"
