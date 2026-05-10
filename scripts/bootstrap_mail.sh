#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
MBSYNCRC="$HOME/.mbsyncrc"
VAULT_FILE="$REPO_ROOT/secrets/vault.yml"
PROTON_FLATPAK_CERT="$HOME/.var/app/ch.protonmail.protonmail-bridge/config/protonmail/bridge-v3/cert.pem"
PROTON_NATIVE_CERT="$HOME/.config/protonmail/bridge-v3/cert.pem"

ACCOUNTS_FILE=$(mktemp)

cleanup() {
  rm -f "$ACCOUNTS_FILE"
}

trap cleanup EXIT INT TERM HUP

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

expand_path() {
  path_value=$1

  case "$path_value" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${path_value#\~/}"
      ;;
    *)
      printf '%s\n' "$path_value"
      ;;
  esac
}

read_secret() {
  prompt=$1
  value=''

  if [ -t 0 ]; then
    printf '%s' "$prompt" >&2
    stty -echo
    IFS= read -r value
    stty echo
    printf '\n' >&2
  else
    printf '%s' "$prompt" >/dev/tty
    stty -echo </dev/tty
    IFS= read -r value </dev/tty
    stty echo </dev/tty
    printf '\n' >/dev/tty
  fi

  printf '%s' "$value"
}

get_vault_icloud_password() {
  if [ ! -f "$VAULT_FILE" ]; then
    return 1
  fi

  first_line=$(awk 'NR == 1 { print; exit }' "$VAULT_FILE")

  if [ "$first_line" = "\$ANSIBLE_VAULT" ] || printf '%s' "$first_line" | grep -q '^\$ANSIBLE_VAULT'; then
    if ! command -v ansible-vault >/dev/null 2>&1; then
      return 1
    fi
    vault_content=$(ansible-vault view "$VAULT_FILE") || return 1
  else
    vault_content=$(cat "$VAULT_FILE")
  fi

  printf '%s\n' "$vault_content" | awk '
    $1 == "vault_icloud_mail_password:" {
      sub(/^[^:]*:[[:space:]]*/, "", $0)
      value = $0
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
  '
}

parse_mbsyncrc() {
  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    function dequote(value) {
      value = trim(value)
      if (value ~ /^".*"$/) {
        sub(/^"/, "", value)
        sub(/"$/, "", value)
      }
      return value
    }

    $1 == "IMAPStore" {
      section = "imap"
      name = $2
      next
    }

    $1 == "MaildirStore" {
      section = "maildir"
      name = $2
      next
    }

    $1 == "Channel" {
      section = "channel"
      name = $2
      channel_order[++channel_count] = name
      next
    }

    section == "imap" && $1 == "User" {
      imap_user[name] = trim(substr($0, index($0, $2)))
      next
    }

    section == "imap" && $1 == "Host" {
      imap_host[name] = trim(substr($0, index($0, $2)))
      next
    }

    section == "imap" && $1 == "Port" {
      imap_port[name] = trim(substr($0, index($0, $2)))
      next
    }

    section == "imap" && $1 == "PassCmd" {
      imap_passcmd[name] = dequote(substr($0, index($0, $2)))
      next
    }

    section == "imap" && $1 == "CertificateFile" {
      imap_certificate[name] = trim(substr($0, index($0, $2)))
      next
    }

    section == "maildir" && $1 == "Path" {
      maildir_path[name] = trim(substr($0, index($0, $2)))
      next
    }

    section == "channel" && $1 == "Far" {
      remote = $2
      gsub(/^:/, "", remote)
      gsub(/:$/, "", remote)
      channel_far[name] = remote
      next
    }

    section == "channel" && $1 == "Near" {
      local_store = $2
      gsub(/^:/, "", local_store)
      gsub(/:$/, "", local_store)
      channel_near[name] = local_store
      next
    }

    END {
      for (i = 1; i <= channel_count; i++) {
        channel = channel_order[i]
        remote = channel_far[channel]
        local_store = channel_near[channel]
        printf "ACCOUNT|%s|%s|%s|%s|%s|%s|%s\n", channel, imap_passcmd[remote], imap_certificate[remote], maildir_path[local_store], imap_user[remote], imap_host[remote], imap_port[remote]
      }
    }
  ' "$MBSYNCRC" >"$ACCOUNTS_FILE"
}

parse_secret_lookup_args() {
  passcmd=$1
  prefix='secret-tool lookup '

  case "$passcmd" in
    "$prefix"*)
      printf '%s\n' "${passcmd#${prefix}}"
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_dbus_session_bus_address() {
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    case "$DBUS_SESSION_BUS_ADDRESS" in
      unix:path=*)
        _path=${DBUS_SESSION_BUS_ADDRESS#unix:path=}
        _path=${_path%%,*}
        if [ -S "$_path" ]; then
          printf '%s\n' "$DBUS_SESSION_BUS_ADDRESS"
          return 0
        fi
        ;;
      unix:abstract=*)
        printf '%s\n' "$DBUS_SESSION_BUS_ADDRESS"
        return 0
        ;;
    esac
  fi

  if [ -f "$HOME/.dbus-session-bus-address" ]; then
    saved_bus_address=$(tr -d '\n' <"$HOME/.dbus-session-bus-address")

    if [ -n "$saved_bus_address" ]; then
      printf '%s\n' "$saved_bus_address"
      return 0
    fi
  fi

  if [ -S "/run/user/$(id -u)/bus" ]; then
    printf 'unix:path=/run/user/%s/bus\n' "$(id -u)"
    return 0
  fi

  return 1
}

clear_secret() {
  lookup_args=$1
  # shellcheck disable=SC2086
  set -- $lookup_args
  secret-tool clear "$@" >/dev/null 2>&1 || true
}

store_secret() {
  label=$1
  lookup_args=$2
  secret=$3

  # shellcheck disable=SC2086
  set -- $lookup_args

  if [ "$#" -eq 0 ] || [ $(( $# % 2 )) -ne 0 ]; then
    printf 'Error: invalid secret-tool lookup arguments: %s\n' "$lookup_args" >&2
    exit 1
  fi

  clear_secret "$lookup_args"
  printf '%s' "$secret" | secret-tool store --label="$label" "$@"

  if ! secret-tool lookup "$@" >/dev/null 2>&1; then
    printf 'Error: failed to verify secret for %s\n' "$label" >&2
    exit 1
  fi
}

ensure_keyring_ready() {
  require_command gdbus
  require_command secret-tool

  if ! DBUS_SESSION_BUS_ADDRESS=$(resolve_dbus_session_bus_address); then
    printf 'Error: could not determine DBUS_SESSION_BUS_ADDRESS. Run this from an active graphical session.\n' >&2
    exit 1
  fi

  export DBUS_SESSION_BUS_ADDRESS

  alias_output=$(gdbus call --session \
    --dest org.freedesktop.secrets \
    --object-path /org/freedesktop/secrets \
    --method org.freedesktop.Secret.Service.ReadAlias default 2>/dev/null) || {
      printf 'Error: could not query GNOME Keyring. Ensure the keyring service is running.\n' >&2
      exit 1
    }

  alias_path=$(printf '%s\n' "$alias_output" | sed -n "s/.*objectpath '\([^']*\)'.*/\1/p" | sed -n '1p')

  if [ -z "$alias_path" ] || [ "$alias_path" = "/" ]; then
    printf 'Error: the default Secret Service collection is unset. Unlock or initialize the login keyring first.\n' >&2
    exit 1
  fi
}

bridge_cli_command() {
  if command -v flatpak >/dev/null 2>&1 && flatpak info ch.protonmail.protonmail-bridge >/dev/null 2>&1; then
    printf '%s\n' 'flatpak run ch.protonmail.protonmail-bridge --cli'
    return 0
  fi

  if command -v protonmail-bridge >/dev/null 2>&1; then
    printf '%s\n' 'protonmail-bridge --cli'
    return 0
  fi

  if command -v bridge >/dev/null 2>&1; then
    printf '%s\n' 'bridge --cli'
    return 0
  fi

  return 1
}

resolve_certificate_file() {
  configured_certificate=$1

  if [ -n "$configured_certificate" ]; then
    expanded_configured_certificate=$(expand_path "$configured_certificate")

    if [ -f "$expanded_configured_certificate" ]; then
      printf '%s\n' "$expanded_configured_certificate"
      return 0
    fi
  else
    expanded_configured_certificate=''
  fi

  for candidate in "$PROTON_FLATPAK_CERT" "$PROTON_NATIVE_CERT"; do
    [ -f "$candidate" ] || continue

    if [ -n "$expanded_configured_certificate" ] && [ "$expanded_configured_certificate" != "$candidate" ]; then
      certificate_dir=$(dirname "$expanded_configured_certificate")
      mkdir -p "$certificate_dir"
      ln -sf "$candidate" "$expanded_configured_certificate"
      printf '%s\n' "$expanded_configured_certificate"
      return 0
    fi

    printf '%s\n' "$candidate"
    return 0
  done

  if [ -n "$expanded_configured_certificate" ]; then
    printf '%s\n' "$expanded_configured_certificate"
  fi

  return 1
}

ensure_certificate_file() {
  account_name=$1
  certificate_file=$2

  if [ -z "$certificate_file" ]; then
    return 0
  fi

  if expanded_certificate_file=$(resolve_certificate_file "$certificate_file"); then
    return 0
  fi

  certificate_dir=$(dirname "$expanded_certificate_file")
  mkdir -p "$certificate_dir"

  bridge_cli=$(bridge_cli_command) || {
    printf 'Error: %s requires %s, but Proton Mail Bridge CLI was not found.\n' \
      "$account_name" "$expanded_certificate_file" >&2
    exit 1
  }

  printf 'Certificate for %s not found at %s\n' "$account_name" "$expanded_certificate_file"
  printf 'Opening Proton Mail Bridge CLI. Export the TLS certificate into: %s\n' "$certificate_dir"
  printf 'Inside Bridge CLI, use `cert export`, choose `%s`, then exit to continue.\n' "$certificate_dir"

  sh -c "$bridge_cli"

  if [ ! -f "$expanded_certificate_file" ]; then
    printf 'Error: certificate still missing at %s after Bridge export.\n' "$expanded_certificate_file" >&2
    exit 1
  fi
}

sync_channels() {
  while IFS='|' read -r record_type channel_name passcmd certificate_file maildir_path email_address host port; do
    [ "$record_type" = 'ACCOUNT' ] || continue
    [ -n "$passcmd" ] || continue

    printf 'Running mbsync for channel %s\n' "$channel_name"
    mbsync "$channel_name"
  done <"$ACCOUNTS_FILE"
}

init_mu() {
  mail_root=''
  mu_addresses=''
  existing_mail_root=''

  while IFS='|' read -r record_type channel_name passcmd certificate_file maildir_path email_address host port; do
    [ "$record_type" = 'ACCOUNT' ] || continue
    [ -n "$maildir_path" ] || continue

    expanded_maildir=$(expand_path "$maildir_path")
    expanded_maildir=${expanded_maildir%/}
    candidate_root=${expanded_maildir%/*}

    if [ -z "$mail_root" ]; then
      mail_root=$candidate_root
    elif [ "$mail_root" != "$candidate_root" ]; then
      printf 'Error: inconsistent Maildir roots in %s (%s vs %s).\n' "$MBSYNCRC" "$mail_root" "$candidate_root" >&2
      exit 1
    fi

    case " $mu_addresses " in
      *" $email_address "*)
        ;;
      *)
        mu_addresses="$mu_addresses $email_address"
        ;;
    esac
  done <"$ACCOUNTS_FILE"

  if [ -z "$mail_root" ]; then
    printf 'Error: no Maildir paths found in %s\n' "$MBSYNCRC" >&2
    exit 1
  fi

  if mu_info=$(mu info 2>/dev/null); then
    existing_mail_root=$(printf '%s\n' "$mu_info" | awk '/^[[:space:]]*maildir[[:space:]]+/ { print $2; exit }')

    if [ -n "$existing_mail_root" ] && [ "$existing_mail_root" != "$mail_root" ]; then
      printf 'Error: mu is initialized for %s, expected %s. Remove the existing mu database before rerunning bootstrap_mail.sh.\n' \
        "$existing_mail_root" "$mail_root" >&2
      exit 1
    fi
  else
    set --
    for email_address in $mu_addresses; do
      set -- "$@" --my-address="$email_address"
    done
    mu init --maildir="$mail_root" "$@"
  fi

  mu index
}

bootstrap_secrets() {
  while IFS='|' read -r record_type channel_name passcmd certificate_file maildir_path email_address host port; do
    [ "$record_type" = 'ACCOUNT' ] || continue
    [ -n "$passcmd" ] || continue

    lookup_args=$(parse_secret_lookup_args "$passcmd") || continue

    case "$lookup_args" in
      'icloud-mail icloud')
        if icloud_password=$(get_vault_icloud_password); then
          :
        else
          icloud_password=$(read_secret 'iCloud app password: ')
        fi

        if [ -z "$icloud_password" ]; then
          printf 'Error: empty iCloud password.\n' >&2
          exit 1
        fi

        store_secret "$channel_name" "$lookup_args" "$icloud_password"
        ;;
      'protonmail-bridge protonmail')
        proton_password=$(read_secret 'Proton Bridge password: ')

        if [ -z "$proton_password" ]; then
          printf 'Error: empty Proton Bridge password.\n' >&2
          exit 1
        fi

        store_secret "$channel_name" "$lookup_args" "$proton_password"
        ensure_certificate_file "$channel_name" "$certificate_file"
        ;;
      *)
        generic_password=$(read_secret "$channel_name password: ")

        if [ -z "$generic_password" ]; then
          printf 'Error: empty password for %s.\n' "$channel_name" >&2
          exit 1
        fi

        store_secret "$channel_name" "$lookup_args" "$generic_password"
        [ -n "$certificate_file" ] && ensure_certificate_file "$channel_name" "$certificate_file"
        ;;
    esac
  done <"$ACCOUNTS_FILE"
}

main() {
  require_command awk
  require_command dirname
  require_command mbsync
  require_command mu

  if [ ! -f "$MBSYNCRC" ]; then
    printf 'Error: mbsync config not found: %s\n' "$MBSYNCRC" >&2
    exit 1
  fi

  parse_mbsyncrc
  ensure_keyring_ready
  bootstrap_secrets
  sync_channels
  init_mu
}

main "$@"
