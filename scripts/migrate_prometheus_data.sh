#!/usr/bin/env sh

# Copy the persistent NPM and Gitea data from the retired Ubuntu server to the Rocky
# replacement. Run this script on the Ubuntu source as root. It is a dry run
# unless --execute and --quiesce-source are both supplied. Extended attributes
# are deliberately not copied: Rocky must assign its own SELinux labels.

set -eu

SOURCE_COMPOSE_FILE=/opt/docker/server/docker-compose.yml
DESTINATION=
IDENTITY_FILE=
EXECUTE=false
QUIESCE_SOURCE=false

DATA_PATHS='
/opt/npm/data
/opt/npm/letsencrypt
/opt/gitea/data
'

usage() {
  cat <<'EOF'
Usage: sudo ./scripts/migrate_prometheus_data.sh --destination USER@HOST [options]

Copies persistent Nginx Proxy Manager and Gitea data to the Rocky server with
rsync. The destination Docker containers must be stopped.

Options:
  --destination USER@HOST  Rocky SSH destination (required).
  --identity PATH         SSH private key readable by root on the source host.
  --source-compose PATH   Source Compose file (default: /opt/docker/server/docker-compose.yml).
  --quiesce-source        Stop the source Compose stack before copying.
  --execute               Perform the transfer; otherwise only show changes.
  -h, --help              Show this help.

The script never deletes source data, destination-only files, containers, or
volumes. It intentionally excludes Syncthing and /home/git/.ssh.
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --destination)
      [ "$#" -ge 2 ] || fail '--destination requires USER@HOST'
      DESTINATION=$2
      shift 2
      ;;
    --identity)
      [ "$#" -ge 2 ] || fail '--identity requires a path'
      IDENTITY_FILE=$2
      shift 2
      ;;
    --source-compose)
      [ "$#" -ge 2 ] || fail '--source-compose requires a path'
      SOURCE_COMPOSE_FILE=$2
      shift 2
      ;;
    --quiesce-source)
      QUIESCE_SOURCE=true
      shift
      ;;
    --execute)
      EXECUTE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[ "$(id -u)" -eq 0 ] || fail 'run this script with sudo on the Ubuntu source host'
[ -n "$DESTINATION" ] || fail '--destination is required'

if [ -n "$IDENTITY_FILE" ]; then
  [ -r "$IDENTITY_FILE" ] || fail "SSH identity is not readable: $IDENTITY_FILE"
  case "$IDENTITY_FILE" in
    *' '*|*"$(printf '\t')"*) fail 'SSH identity paths must not contain whitespace' ;;
  esac
fi

if [ "$EXECUTE" = true ] && [ "$QUIESCE_SOURCE" != true ]; then
  fail '--execute requires --quiesce-source to keep application data consistent'
fi

require_command rsync
require_command ssh

SSH_COMMAND='ssh -o BatchMode=yes'
if [ -n "$IDENTITY_FILE" ]; then
  SSH_COMMAND="$SSH_COMMAND -i $IDENTITY_FILE"
fi

run_ssh() {
  # shellcheck disable=SC2086
  $SSH_COMMAND "$DESTINATION" "$@"
}

printf 'Destination: %s\n' "$DESTINATION"
printf 'Mode: %s\n' "$( [ "$EXECUTE" = true ] && printf execute || printf dry-run )"
printf 'Data paths:\n%s\n' "$DATA_PATHS"

run_ssh 'sudo -n true' || fail 'destination sudo must be passwordless for this transfer'
run_ssh 'sudo -n docker info >/dev/null' \
  || fail 'destination Docker daemon is unavailable'
if run_ssh 'sudo -n docker ps -q | grep -q .'; then
  fail 'destination Docker containers must be stopped before migration'
fi

for path in $DATA_PATHS; do
  [ -d "$path" ] || fail "source directory is missing: $path"
  run_ssh "sudo -n test -d $path" || fail "destination directory is missing: $path"
done

if [ "$QUIESCE_SOURCE" = true ]; then
  require_command docker
  [ -f "$SOURCE_COMPOSE_FILE" ] || fail "source Compose file is missing: $SOURCE_COMPOSE_FILE"

  if [ "$EXECUTE" = true ]; then
    printf 'Stopping source Compose stack...\n'
    docker compose -f "$SOURCE_COMPOSE_FILE" stop
  else
    printf 'Dry-run: source Compose stack would be stopped.\n'
  fi
fi

for path in $DATA_PATHS; do
  printf '\nSyncing %s\n' "$path"
  if [ "$EXECUTE" = true ]; then
    rsync -aHA --numeric-ids --itemize-changes --human-readable --partial \
      --rsync-path='sudo -n rsync' -e "$SSH_COMMAND" "$path/" "$DESTINATION:$path/"
  else
    rsync -aHA --numeric-ids --itemize-changes --human-readable --partial --dry-run \
      --rsync-path='sudo -n rsync' -e "$SSH_COMMAND" "$path/" "$DESTINATION:$path/"
  fi
done

if [ "$EXECUTE" = true ]; then
  printf '\nVerifying source-to-destination parity...\n'
  for path in $DATA_PATHS; do
    rsync -aHA --numeric-ids --itemize-changes --dry-run \
      --rsync-path='sudo -n rsync' -e "$SSH_COMMAND" "$path/" "$DESTINATION:$path/"
  done
  printf '\nTransfer completed. Keep the source stack stopped until application validation on Rocky succeeds.\n'
else
  printf '\nDry-run completed. Re-run with --quiesce-source --execute after reviewing the changes.\n'
fi
