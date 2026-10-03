# Prometheus NPM Quadlet cutover

## Current state (2026-10-03)

Nginx Proxy Manager runs as the **rootful** generated
`prometheus-npm.service` on Prometheus. The Quadlet files are
`/etc/containers/systemd/prometheus-npm.container` and
`/etc/containers/systemd/server-web.network`; the image is pinned by digest
in `ansible/inventory/host_vars/prometheus.yml`. The generated service is
wanted by `multi-user.target` and requires the generated network service.
The old `podman-compose-server.service` is inactive and disabled. Its unit
and Compose file remain as a rollback option, not as another active owner.
Do not start both units or run `podman-compose down` while the Quadlet owns
the shared `server_web` network.

There was **no data copy** in this cutover. The Quadlet reuses the existing
`/opt/npm/data:/data` and `/opt/npm/letsencrypt:/etc/letsencrypt` bind mounts
with the same container name and `server_web` bridge (`10.89.0.0/24`). Ports
80 and 443 remain public; administration port 81 remains bound to
`127.0.0.1`. Gitea stays on Atlas, and NPM remains on Prometheus. The
Prometheus Compose file is retained with the same pinned NPM image for a
controlled fallback. The Quadlet uses `Pull=missing`, not an automatic
floating-tag update.

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

A future rollback is a separate outage decision, not an ordinary Ansible run.
First verify a usable recent Atlas backup and stop the export timer. Stop
the Quadlet and verify that its container is gone before allowing Compose
to own the same name, mounts, network, and ports; use the pinned Compose
configuration, then validate NPM/HTTPS and restart the timer. Set
`server_npm_quadlet_cutover: false` only as part of that controlled rollback.
Do not run the two owners concurrently, restore an old NPM database over a
live instance, or delete either bind mount. This reverse procedure has not
been exercised on production; the forward script's in-window rollback path
is not evidence of a later reverse cutover.

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
sudo systemctl is-active podman-compose-server.service
sudo systemctl is-enabled podman-compose-server.service
```

The backup archive includes credentials, certificates, and WireGuard
configuration. Do not publish it or print its contents in diagnostics; see
`docs/prometheus-backup.md` for the restricted pull and restore procedure.
