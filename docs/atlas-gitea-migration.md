# Gitea migration from Prometheus to Atlas

This is a staged migration plan, not a cutover authorization. Keep the source
Gitea, its data, both NPM Proxy Hosts, and public DNS unchanged until the
target and rollback have been tested. Gitea is temporary on Atlas until
Uranus; NPM remains on Prometheus.

## Observed source and chosen topology (2026-10-01)

- Prometheus runs the rootful `docker.gitea.com/gitea:1.25.2` image in its
  managed Compose stack. `/opt/gitea/data` is about 280 MiB, uses SQLite,
  and contains 33 repositories. A live read-only SQLite `quick_check` passed.
  `/home/git/.ssh` is a separate small bind mount; `/opt/gitea/data/ssh`
  contains the existing SSH host keys. Neither tree may be discarded.
- Gitea answers HTTP 200 on Prometheus port 3000. NPM currently forwards
  `git.fscotto.duckdns.org` and `git.ov-ad3410.infomaniak.ch` to the Compose
  hostname `gitea:3000`. Public DNS resolves to Prometheus. The container's
  SSH port is bound only to `127.0.0.1:222`; this is not a public Gitea SSH
  listener. Prometheus' public port 22 remains administrative SSH.
- Atlas has a healthy pool and a verified, private Prometheus backup under
  `/zpool/backup/hosts/prometheus/latest`. The 2026-10-01 scheduled export
  and pull succeeded. The intended target is a separate
  `/zpool/services/data/gitea` dataset, not `Archive` or the backup dataset.
- The approved cutover keeps NPM on Prometheus, changes the two HTTP Proxy
  Hosts to Atlas over the Prometheus--Aegis gateway, and offers public Gitea
  SSH on port 2222 via the same gateway. Prometheus port 22 is unchanged.
  HTTPS and SSH must be validated together before declaring cutover.
- Run Gitea as a **rootless user Quadlet** under a dedicated, non-login Atlas
  account, using the pinned `1.25.2-rootless` image. This is an explicit
  rootful-to-rootless **data-layout conversion**, not a drop-in image swap:
  the target mounts `/var/lib/gitea` and `/etc/gitea`, and uses Gitea's
  built-in SSH server instead of the source image's OpenSSH daemon. Keep the
  application version unchanged until the conversion has passed an isolated
  restore test. The host's rootful Quadlet directory must not be used.

## Phase 1: prepare without traffic changes

Preparation completed on 2026-10-01: Ansible created
`zpool/services/data/gitea`, a dedicated non-login `gitea` account (UID/GID
1101), separate subordinate IDs, parent-dataset traverse ACLs, and an inactive
user Quadlet under `/var/lib/atlas-gitea/.config/containers/systemd/`. The
Quadlet has no `[Install]` section and, until the final cutover, binds only
loopback staging ports 3001/2223 if started manually. A second targeted
Ansible run changed nothing; the generated service was inactive and neither
staging port listened. **No Gitea payload has been restored to the target.**

1. Provision a dedicated target dataset and non-login service identity via
   Ansible, keeping UID/GID distinct from Atlas' reserved Immich `1100`.
   Install the user Quadlet in that identity's
   `~/.config/containers/systemd/`, **without** an `[Install]` section;
   do not enable, start, or expose it yet.
2. Verify the selected Atlas backup SHA-256 and metadata, then extract **only**
   `opt/gitea/data` and `home/git/.ssh` to private staging. Never unpack NPM,
   WireGuard, or other host configuration from this sensitive tarball into a
   live namespace. Convert the rootful `/data` tree on a disposable copy:
   place application data under `/var/lib/gitea`, move `app.ini` to
   `/etc/gitea`, and rewrite every absolute `/data/...` path for the new
   layout. Enable `START_SSH_SERVER`, use internal SSH port 2222, and retain
   the source host-key pairs for the built-in server only after verifying
   their fingerprints and compatibility. Do not rely on the old
   `/home/git/.ssh` OpenSSH mount in the rootless image. Set only the target
   copy's ownership and path-scoped SELinux labels.
3. Validate SQLite integrity, repository count and representative `git fsck`,
   LFS/attachment presence, permissions, and an isolated rootless test
   container with no production ingress or outbound network. Because the
   source stays active, this is a rehearsal copy, not the final cutover copy.
   Regenerate Git hooks if the changed installation path requires it.
4. Confirm that Atlas snapshots, Borg, and offline USB include the new dataset;
   test at least one independent restore before user traffic is accepted.

## Phase 2: explicit final cutover

1. Agree on an outage and record source/target versions, pool health, the
   latest backups, SSH host-key fingerprints, and both current NPM routes.
   Stop the Prometheus export timer for the change window so it cannot
   restart the old Compose stack unexpectedly.
2. Quiesce source writes. Run one final consistent Prometheus export, pull it
   to Atlas, verify checksum and timestamp, then stop the source Gitea. Keep
   `/opt/gitea/data` and `/home/git/.ssh` intact for rollback. Do not allow
   source Gitea to restart after accepting writes on Atlas.
3. Restore the final Gitea-only payload to the target and repeat integrity
   checks. Set Gitea's advertised SSH port to 2222 while retaining its
   existing HTTPS `ROOT_URL` and verified host keys. Start the pinned rootless
   Atlas user Quadlet,
   initially without public ingress; validate local HTTP, SQLite, repositories,
   LFS/attachments, and SSH host-key identity.
4. Permit only Aegis' source-NAT address to reach Atlas' Gitea HTTP and SSH
   ports. Enable the public TCP/2222 forward on Prometheus to Atlas over Aegis
   without changing administrative TCP/22. Update **both** NPM Proxy Hosts
   from `gitea:3000` to Atlas' HTTP endpoint. Do not change public DNS.
5. Test HTTPS login, representative clone/push, LFS, and public SSH clone/push
   on port 2222 from outside the Atlas LAN. Record the last source write and
   first healthy target service times; do not claim RPO/RTO without measuring.
6. Only after successful traffic validation, remove Gitea from Prometheus'
   desired Compose stack and its backup-export path/container checks, leaving
   NPM and its backups operational. Do not delete the old data. Verify the
   next Atlas snapshot/Borg run covers Gitea and test a restored target copy.

## Rollback gate

Before Atlas accepts writes, revert the two NPM routes, disable the public
2222 forward, and restart the unchanged source Gitea if target validation
fails. **After Atlas accepts writes, do not blindly restart the source:** its
SQLite database and repositories are stale. Quiesce Atlas, capture its new
data, and decide a reverse migration or an extended outage explicitly.

Upstream references: [rootful container layout](https://docs.gitea.com/1.25/installation/install-with-docker/),
[rootless image layout and incompatibility](https://docs.gitea.com/installation/install-with-docker-rootless/),
[rootless Podman Quadlet](https://docs.gitea.com/installation/install-with-podman-quadlet/),
[standard-image conversion](https://docs.gitea.com/1.24/installation/install-with-docker-rootless/),
and [restore and hook regeneration](https://docs.gitea.com/1.26/administration/backup-and-restore/).
