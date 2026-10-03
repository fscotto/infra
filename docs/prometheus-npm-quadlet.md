# Prometheus NPM Quadlet cutover

## Current state (2026-10-03)

Nginx Proxy Manager runs as the **rootful** generated
`prometheus-npm.service` on Prometheus. The Quadlet files are
`/etc/containers/systemd/prometheus-npm.container` and
`/etc/containers/systemd/server-web.network`; the image is pinned by digest
in `ansible/inventory/host_vars/prometheus.yml`. The generated service is
wanted by `multi-user.target` and requires the generated network service.
The old Compose unit, Compose file and Gitea final-export helper were
removed by the operator-approved cleanup on 2026-10-03. The retired
application data and empty legacy directories were also removed.
Prometheus host vars set `server_legacy_stack_retired: true` so normal runs
do not recreate those files. Destructive deletion still requires a separate
cleanup tag and explicit extra-var.

There was **no data copy** in this cutover. The Quadlet reuses the existing
`/opt/npm/data:/data` and `/opt/npm/letsencrypt:/etc/letsencrypt` bind mounts
with the same container name and `server_web` bridge (`10.89.0.0/24`). Ports
80 and 443 remain public; administration port 81 remains bound to
`127.0.0.1`. Gitea stays on Atlas, and NPM remains on Prometheus. The
Compose fallback is no longer installed. The Quadlet uses `Pull=missing`,
not an automatic floating-tag update.

## Cutover and recovery boundaries

The separate `scripts/cutover_prometheus_npm_quadlet.sh` was run **once** in
the approved outage window, after source backup version
`20261003T091009Z` was checksum-verified and pulled to Atlas. Its preflight
required exactly the Compose owner, an inactive generated Quadlet, the
expected image, and the current backup version. The execution held the
backup-export lock, stopped the export timer, stopped and disabled Compose,
started the Quadlet, checked the exact image ID, SQLite database counts,
certificate content, Nginx configuration, and local Gitea/Syncthing HTTPS,
then restarted the timer. Its failure trap would have restarted Compose.
**Do not rerun that forward-cutover script after success**: its preconditions
intentionally reject an active Quadlet.

Recovery is now a Quadlet rebuild and restoration from a verified Atlas
backup, with an explicit outage decision before replacing live NPM state.
The old Compose owner is no longer installed; reintroducing it would require
a separately reviewed configuration and outage plan. The historical
in-window rollback trap is not a supported post-cleanup rollback procedure.
Do not restore an old database over a live instance or remove NPM bind mounts.

## Verified evidence

- Immediately after cutover, `prometheus-npm.service` was active with zero
  recorded restarts; Compose was inactive/disabled. The generated
  `multi-user.target.wants` link and network dependency were present. An
  actual reboot has not been performed solely for this test.
- The running image ID matched the prior Compose image. Podman showed the
  original two bind mounts, `server_web`, public 80/443, and loopback-only 81.
  External HTTPS to Gitea and Syncthing returned 200 with TLS verification
  result 0. External access to TCP/81 timed out.
- The first **manual post-cutover** export `20261003T091633Z` succeeded with
  the Quadlet as its active owner. The Atlas pull published that version;
  its SHA-256 payload check passed. An isolated restore passed NPM SQLite
  `quick_check` with ten proxy hosts and six certificate records. Both
  Quadlet definitions were present in the tar archive.
- A path/content manifest of all 70 regular Let's Encrypt files and the
  path/target manifest of all 12 symlinks in the Atlas archive exactly
  matched the live Prometheus tree (aggregate SHA-256
  `ce0965fbd3ff44bb8502ed9f314e0131edd86d822039de115b39f6a2273c2da8`).
  The earlier apparent 70-vs-82 count was only a regular-file-versus-symlink
  counting difference, not missing certificate data. No certificate key
  contents were exposed during comparison.
- The targeted `--tags npm_quadlet` normal Ansible run completed with
  `changed=0`, and the backup export timer remained active/enabled.

The first unattended 02:00 Europe/Rome export and 03:00 Atlas pull **after**
this cutover have not yet occurred. Check their service results and the
published version after the next cycle; the successful manual cycle proves
the new path works but not its next scheduled execution.

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit prometheus --tags npm_quadlet --check --diff
sudo systemctl status prometheus-npm.service prometheus-backup-export.timer
sudo systemctl show podman-compose-server.service -p LoadState # expected: not-found
```

The backup archive includes credentials, certificates, and WireGuard
configuration. Do not publish it or print its contents in diagnostics; see
`docs/prometheus-backup.md` for the restricted pull and restore procedure.

## Selective legacy image cleanup

On 2026-10-03 opt-in Ansible tasks removed only the unused Gitea 1.25.2,
Navidrome latest and PostgreSQL 13 rootful images, without force or global
prune. Podman refuses images referenced by existing containers. The second
run changed nothing. NPM remained active with zero restarts; local admin
and public Gitea HTTPS returned 200. Backup timer and SSH proxy stayed active.

Validation:
```bash
ansible-playbook ansible/site.yml --limit prometheus --tags server_image_cleanup --check --diff -e server_legacy_image_cleanup=true
```

The image cleanup defaults to disabled and carries the `never` tag.
Check mode probes image presence but skips removal; it does not prove
Podman would accept deletion. It never removes NPM resources.

## Approved legacy data and fallback cleanup

The operator explicitly approved deletion on 2026-10-03. The separate
`server_legacy_cleanup` tasks removed `/opt/gitea`, `/home/git/.ssh`,
`/opt/navidrome`, `/opt/postgres`, `/opt/music`, `/opt/containerd`,
`/opt/docker`, the old Compose unit and the final Gitea export helper.
The empty `/home/git` parent is removed only with `rmdir`, after confirming
the Git account is absent. Guards reject symlinked paths, nested mounts,
unexpected containers, container users of these paths, unexpected content
in the empty legacy trees, and an active Compose or export service.
The second cleanup run changed nothing.

Before deletion, Ansible removed obsolete backup input paths and the
Gitea mount dependency. Normal Compose/template/final-export task checks
changed nothing and did not recreate the retired files. Deletion is opt-in:

```bash
ansible-playbook ansible/site.yml --limit prometheus --tags server_legacy_cleanup --check --diff -e server_legacy_cleanup=true
```

Remove check mode only for approved deletion. No active NPM data, certificate,
image, network, volume, SSH proxy, WireGuard configuration or backup archive
is removed. No services were restarted by the cleanup.

After separate approval for the brief managed NPM pause, the new export
`20261003T112906Z` completed successfully and was pulled to Atlas. SHA-256
passed on both hosts; an isolated SQLite restore passed `quick_check` and
contained ten proxy hosts. Both Quadlet definitions were present, and
retired paths were absent. Temporary restore files were removed.
NPM was active with zero automatic restarts; primary public Gitea HTTPS
returned 200 with valid TLS. Backup timer, SSH proxy and WireGuard stayed active.
The first scheduled post-cleanup cycle remains unverified.

After separate operator approval on 2026-10-03, the unused secondary hostname
`git.ov-ad3410.infomaniak.ch` was removed from the declared domains and
the managed NPM runtime override. Its Proxy Host (id 10) was already
soft-deleted, with no generated config or associated certificate. Historical
deleted records and backup archives are preserved; no DNS changes were made.
Only `git.fscotto.duckdns.org` remains declared for the Gitea override.
Nginx validation and reload passed without restarting NPM; the primary
public HTTPS endpoint returned 200 with valid TLS.
