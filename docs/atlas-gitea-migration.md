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
- Preserve the same **rootful** Gitea image and `/data` layout at first. The
  upstream rootless image uses different mount paths and SSH implementation;
  changing image type during a data migration is not a drop-in operation.
  Pin the same version initially; consider upgrades separately.

## Phase 1: prepare without traffic changes

1. Provision a dedicated target dataset and non-login service identity via
   Ansible, keeping UID/GID distinct from Atlas' reserved Immich `1100`.
   Install a rootful Quadlet but do not start it or open firewall ports yet.
2. Verify the selected Atlas backup SHA-256 and metadata, then extract **only**
   `opt/gitea/data` and `home/git/.ssh` to private staging. Never unpack NPM,
   WireGuard, or other host configuration from this sensitive tarball into a
   live namespace. Preserve Gitea's existing SSH host keys; adjust ownership
   to the declared Atlas service UID/GID and apply only path-scoped SELinux
   labels needed by the container.
3. Validate SQLite integrity, repository count and representative `git fsck`,
   LFS/attachment presence, permissions, and a test container with no
   production ingress or outbound network. Because the source stays active,
   this is a rehearsal copy, not the final cutover copy. Regenerate Git hooks
   if the changed installation path requires it, as documented by Gitea.
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
   existing HTTPS `ROOT_URL` and host keys. Start the pinned Atlas container,
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
[rootless incompatibility](https://docs.gitea.com/installation/install-with-docker-rootless/),
and [restore and hook regeneration](https://docs.gitea.com/1.26/administration/backup-and-restore/).
