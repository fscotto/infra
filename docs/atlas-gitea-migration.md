# Gitea migration from Prometheus to Atlas

Historical record: the completed owner-migration, migration-restore and final-export
tasks, helpers and flags have been removed from the repository. Commands below
record past execution, not currently supported migration entry points. Current
service safety checks, recurring backups and proxy configuration remain managed.

The later 2026-10-03 canonical-domain change to `git.fscotto.co` is recorded
in `docs/domain-fscotto-co.md`. Public SSH remains on TCP/2222; the old
DuckDNS Proxy Host was observed disabled. Earlier domain references below
describe migration evidence, not the current canonical URL.

This records the staged migration and its observed partial cutover. Gitea is
temporary on Atlas until Uranus; NPM remains on Prometheus. On 2026-10-03
the operator explicitly approved removal of the old Prometheus Gitea data,
SSH fragment and final-export helper. NPM now uses a rootful Quadlet with no
installed Compose fallback. The source-retention and rollback steps below
are historical migration gates, not current recovery instructions.
Existing backup archives were preserved; use current Atlas data and verified
backups for recovery. Do not recreate or restart stale source Gitea.

## Observed source before cutover and chosen topology (2026-10-01)

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
  Hosts' effective upstream to Atlas over the Prometheus--Aegis gateway, and offers public Gitea
  SSH on port 2222 via the same gateway. Prometheus port 22 is unchanged.
  HTTPS and SSH must be validated together before declaring cutover.
- The initial staging ran as a **rootless user Quadlet** under a dedicated,
  non-login Atlas account, using the pinned `1.25.2-rootless` image. This was an explicit
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
staging port listened.

The explicit rehearsal is managed by:

```bash
ansible-playbook ansible/site.yml --limit atlas --tags gitea_restore \
  -e atlas_gitea_restore_test=true
```

On 2026-10-01 this selected the latest verified Prometheus backup, checked its
SHA-256, extracted only `opt/gitea/data`, moved `app.ini` into the rootless
config mount, rewrote `/data/` paths, enabled built-in SSH on internal port
2222, and retained the three source SSH host-key pairs. SQLite `quick_check`
passed, all 33 restored repositories passed `git fsck`, and each source/target
public host-key fingerprint matched. A temporary `1.25.2-rootless` container
with `--network none` answered HTTP internally and listened on internal
SSH/2222. The container was removed; the user Quadlet remains inactive, with
no staging listener. The second restore run changed nothing. This copy is
deliberately stale once new source writes occur and **must not** be used as the
final cutover copy.

Target backup checks on 2026-10-01: the managed recursive hourly ZFS snapshot
`atlas-auto-hourly-20261001T193401Z` contains the new dataset. The managed
Borg service completed archive `atlas-20261001T193420Z`, whose contents list
includes the staged Gitea database. A separate one-file restore from each
source into private `/var/tmp` directories matched the live staged database
and passed SQLite `quick_check`. Temporary files and the on-demand snapshot
mount were removed; the Borg temporary snapshot was cleaned up and the pool
remained healthy. This is file-level proof, **not** a full Gitea recovery.
The operator's UUID-bound offline USB run published version
`20261001T201220Z-254397` on 2026-10-02. A separate read-only mount and
temporary restore of `services/data/gitea/data/gitea/gitea.db` matched
contents, owner, group, mode, size, mtime and POSIX ACL; SQLite
`quick_check` returned `ok`. The temporary mount and copy were removed,
LUKS was closed, and the pool was healthy. This is a file-level restore test,
not a complete Gitea recovery rehearsal from USB.

1. Provision a dedicated target dataset and non-login service identity via
   Ansible, keeping UID/GID distinct from Atlas' reserved Immich `1100`.
   Install the user Quadlet in that identity's
   `~/.config/containers/systemd/`, **without** an `[Install]` section;
   do not enable, start, or expose it yet.
2. Verify the selected Atlas backup SHA-256 and metadata, then extract **only**
   `opt/gitea/data` to private staging. Keep `home/git/.ssh` in the source
   backup for rollback; the rootless image does not consume its OpenSSH mount.
   Never unpack NPM,
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
4. ZFS, Borg and UUID-bound offline USB inclusion and one-file restores have
   passed. These do not replace the final consistent source copy.

## Phase 2: explicit final cutover

The opt-in `/usr/local/sbin/prometheus-gitea-final-export` helper was installed
on 2026-10-01 and passed `bash -n`. It refuses to
run while the scheduled Prometheus export timer is active. When explicitly
triggered, it stops only the source Gitea container, checks SQLite, publishes
a checksum-verified Gitea-only version for Atlas' existing pull, and leaves
the source stopped on success. NPM remains running. A failure before
completion restarts source Gitea. Its Ansible gate is
`--tags gitea_final_export -e server_gitea_final_export=true`.
After Atlas pulls that version, its separate
`--tags gitea_final_restore -e atlas_gitea_final_restore=true` gate accepts
only metadata marked `gitea-cutover`, validates a private staged replacement,
and swaps it for the marked rehearsal. The swap and its rollback path passed
synthetic tests on 2026-10-01; the live gate succeeded on 2026-10-02.

On 2026-10-02 the operator approved the outage. The final stopped-source
export `20261002T071525Z` passed the Atlas pull checksum; the guarded restore
replaced the rehearsal. SQLite `quick_check`, all 33 repository `git fsck`
checks, and the source/target SSH host-key comparison passed. The rootless
Atlas Quadlet serves LAN HTTP/3000 and SSH/2222, reachable from Prometheus
through Aegis; its firewall admits only Aegis. The final marker gates startup.

Prometheus now runs the NPM-only Compose stack. Both NPM database records still
say `gitea:3000`, but Nginx evaluates this variable upstream through its
runtime DNS resolver, which **does not** use a Compose `extra_hosts` alias.
The initial alias attempt returned 502. A managed `server_proxy.conf` override
sets `$server` to Atlas' IP for only the two declared Gitea domains; it passed
`nginx -t` and primary HTTPS/API returned 200 after a clean NPM restart
without the alias; a representative public `git ls-remote` also succeeded.
Navidrome and Syncthing Proxy Hosts still responded. No NPM SQLite records
or credentials were changed. The
secondary hostname `git.ov-ad3410.infomaniak.ch` did not resolve from Ikaros
and had no generated NPM config file at the time of inspection.

On 2026-10-03 the operator retired this unused secondary hostname. Its NPM
Proxy Host was already soft-deleted; Ansible now declares only
`git.fscotto.duckdns.org` and removes the secondary runtime override.

Prometheus' public TCP/2222 socket proxies to Atlas without changing admin
SSH/22. The local socket presents the preserved Gitea ED25519 host key, but
an external TCP/2222 connection from Ikaros initially timed out. During that
test no SYN reached Prometheus `eth0`; its socket and firewalld port were active.
After the VPS firewall was opened later on 2026-10-02, the public port connected,
its ED25519 host-key fingerprint matched Atlas, Gitea authenticated the `ikaros`
key as `fscotto`, and a public SSH `git ls-remote` for `fscotto/infra.git`
returned HEAD. The operator subsequently reported successful authenticated
SSH pull and push; the agent did not perform a write test. HTTPS write/login
remain untested. Do not
restart the stale source after public HTTPS has accepted target writes.

The Prometheus export timer resumed with NPM-only paths. A recursive ZFS
snapshot at `20261002T073032Z` and encrypted Borg archive
`atlas-20261002T073044Z` captured the Atlas target after cutover; Borg exited
successfully, cleaned its temporary snapshot, and the pool was healthy.

## Corrected Atlas service owner (2026-10-02)

The operator required the host Quadlet to belong to `admin`, while the Unix
user **inside** the container must be named `gitea`. The pinned derived
`Containerfile.gitea-rootless` changes only the base image's UID/GID 1000
passwd/group names from `git` to `gitea`; it retains the rootless image's
paths and entrypoint. Gitea's `RUN_USER` is `gitea`, while its built-in SSH
user and advertised clone user remain `git`, preserving `git@` URLs. The
selective restore helper now generates the same three settings for any future
explicit restore, instead of recreating a `RUN_USER = git` target.

A disposable, loopback-only container using a copy of a Gitea ZFS snapshot
passed HTTP, SQLite, internal-user and SSH host-key checks without touching
live data. After explicit outage approval, the opt-in
`--tags gitea_owner_migration -e atlas_gitea_owner_migration=true` run stopped
the old user service, took safety snapshot
`zpool/services/data/gitea@gitea-owner-migration-20261002T100104`, transferred
only the Gitea dataset to `admin`, tested an `admin` staging Quadlet on
loopback, then promoted it to the production LAN ports. The old Atlas Quadlet
was removed. The old host `gitea` account and its sub-ID range are retained
for a deliberate rollback; they must not restart stale Gitea. The parent
traverse ACL is removed by the normal Gitea role once the new owner is live.

The new service returned HTTP 200 locally and through public primary HTTPS;
Navidrome and Syncthing remained active under `admin`, the pool was healthy,
and a second normal Gitea Ansible run was idempotent. This does **not** close
the separate external TCP/2222 or authenticated clone/push validation gap.

1. Agree on an outage and record source/target versions, pool health, the
   latest backups, SSH host-key fingerprints, and both current NPM routes.
   Stop the Prometheus export timer for the change window so it cannot
   restart the old Compose stack unexpectedly.
2. Quiesce source writes with the final-export helper: it stops Gitea before
   the consistent export and leaves it stopped after success. Pull that export
   to Atlas and verify checksum and timestamp. Keep
   `/opt/gitea/data` and `/home/git/.ssh` intact for rollback. Do not allow
   source Gitea to restart after accepting writes on Atlas.
3. Restore the final Gitea-only payload to the target and repeat integrity
   checks. Verify its advertised SSH port is 2222, its existing HTTPS
   `ROOT_URL`, repositories, LFS/attachments, and SSH host-key identity. Enable
   the production Atlas Quadlet only after the final-restore marker exists;
   its firewall permits only Aegis to reach HTTP and SSH. Validate local HTTP
   and the target service before switching NPM.
4. Enable the public TCP/2222 socket proxy on Prometheus to Atlas over Aegis
   without changing administrative TCP/22. Switch Prometheus to the desired
   NPM-only Compose stack and use the managed Gitea-only NPM runtime upstream
   override. Do not use Compose `extra_hosts`: Nginx bypasses it for the
   variable upstream. The old Gitea data stays intact. Do not change public DNS.
5. Test HTTPS login, representative clone/push, LFS, and public SSH clone/push
   on port 2222 from outside the Atlas LAN. Record the last source write and
   first healthy target service times; do not claim RPO/RTO without measuring.
6. Resume the Prometheus NPM-only backup export timer after the desired stack
   is active and verify its next result. Verify the next Atlas snapshot/Borg
   run covers Gitea and test a restored target copy. Do not delete old source
   data.

## Rollback gate

Before Atlas accepts writes, restore the old Compose definition and remove the
NPM override, disable the public 2222 proxy, and restart the unchanged source
Gitea if target validation fails. **After Atlas accepts writes, do not blindly restart the source:** its
SQLite database and repositories are stale. Quiesce Atlas, capture its new
data, and decide a reverse migration or an extended outage explicitly.

Upstream references: [rootful container layout](https://docs.gitea.com/1.25/installation/install-with-docker/),
[rootless image layout and incompatibility](https://docs.gitea.com/installation/install-with-docker-rootless/),
[rootless Podman Quadlet](https://docs.gitea.com/installation/install-with-podman-quadlet/),
[standard-image conversion](https://docs.gitea.com/1.24/installation/install-with-docker-rootless/),
and [restore and hook regeneration](https://docs.gitea.com/1.26/administration/backup-and-restore/).
