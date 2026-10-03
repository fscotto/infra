#!/usr/bin/env bash
# Run on Prometheus as root with the exact verified source-export version.
set -Eeuo pipefail

expected_export=${1:?Pass the verified Prometheus backup export version}
mode=${2:---preflight}
[[ $expected_export =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || exit 2
[[ $mode == --preflight || $mode == --execute ]] || exit 2
[[ $EUID -eq 0 ]] || { echo 'Run as root on Prometheus' >&2; exit 2; }

compose_unit=podman-compose-server.service
quadlet_unit=prometheus-npm.service
backup_timer=prometheus-backup-export.timer
versions=/var/lib/prometheus-backup-export/versions
quadlet_file=/etc/containers/systemd/prometheus-npm.container

exec 9>/run/lock/prometheus-backup-export.lock
flock -n 9 || { echo 'Backup/export lock is busy' >&2; exit 1; }

systemctl is-active --quiet "$compose_unit"
if systemctl is-active --quiet "$quadlet_unit"; then
  echo 'NPM Quadlet is already active; refusing overlapping cutover' >&2
  exit 1
fi
[[ $(systemctl show "$quadlet_unit" -p LoadState --value) == loaded ]]
[[ $(systemctl is-enabled "$compose_unit") == enabled ]]
[[ $(readlink "$versions/current") == "$expected_export" ]]
image=$(sed -n 's/^Image=//p' "$quadlet_file")
[[ $image =~ ^docker\.io/jc21/nginx-proxy-manager@sha256:[a-f0-9]{64}$ ]]
podman image exists "$image"
(cd "$versions/current" && sha256sum -c payload.sha256 && tar -tf payload.tar >/dev/null)
curl -fsS --connect-timeout 2 --max-time 5 -o /dev/null http://127.0.0.1:81/
old_image=$(podman inspect nginx-proxy-manager --format '{{.Image}}')

data_signature() {
  python3 - <<'PY'
import hashlib, os, sqlite3
db = sqlite3.connect('file:/opt/npm/data/database.sqlite?mode=ro', uri=True)
assert db.execute('pragma quick_check').fetchone()[0] == 'ok'
counts = [db.execute('select count(*) from ' + table).fetchone()[0]
          for table in ('proxy_host', 'certificate', 'user')]
db.close()
digest = hashlib.sha256()
for root, dirs, files in os.walk('/opt/npm/letsencrypt'):
    dirs.sort()
    for name in sorted(files):
        path = os.path.join(root, name)
        with open(path, 'rb') as stream:
            digest.update(path.encode() + b'\0' + stream.read())
print(*counts, digest.hexdigest())
PY
}
before=$(data_signature)
if [[ $mode == --preflight ]]; then
  echo 'NPM Quadlet cutover preflight passed; no service was changed'
  exit 0
fi

stopped_old=false
rollback() {
  rc=$?
  trap - EXIT
  if (( rc != 0 )) && "$stopped_old"; then
    echo 'NPM Quadlet cutover failed; restoring Compose' >&2
    systemctl stop "$quadlet_unit" || true
    systemctl enable "$compose_unit" || true
    systemctl start "$compose_unit" || true
    systemctl start "$backup_timer" || true
    curl -fsS --connect-timeout 2 --max-time 10 -o /dev/null http://127.0.0.1:81/ || true
  fi
  exit "$rc"
}
trap rollback EXIT

stopped_old=true
systemctl stop "$backup_timer"
systemctl stop "$compose_unit"
if podman container exists nginx-proxy-manager; then
  echo 'Compose left the NPM container behind; refusing duplicate ownership' >&2
  exit 1
fi
systemctl disable "$compose_unit"
systemctl start "$quadlet_unit"

ready=false
for _ in {1..60}; do
  if curl -fsS --connect-timeout 2 --max-time 3 -o /dev/null http://127.0.0.1:81/; then
    ready=true
    break
  fi
  sleep 2
done
"$ready"
systemctl is-active --quiet "$quadlet_unit"
[[ $(podman inspect nginx-proxy-manager --format '{{.Image}}') == "$old_image" ]]
podman exec nginx-proxy-manager nginx -t
[[ $(data_signature) == "$before" ]]
for hostname in git.fscotto.duckdns.org syncthing.fscotto.duckdns.org; do
  status=$(curl -ksS --connect-timeout 3 --max-time 10 \
    --resolve "$hostname:443:127.0.0.1" -o /dev/null -w '%{http_code}' \
    "https://$hostname/")
  [[ $status == 200 ]]
done
systemctl start "$backup_timer"
stopped_old=false
echo 'NPM Quadlet cutover passed local application and data checks'
