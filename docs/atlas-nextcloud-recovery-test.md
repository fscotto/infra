# Nextcloud manual backup/restore rehearsal — 2026-10-04

## Observed outcome

The operator authorized testing consistent database/files backup and recovery.
This was executed directly, not added as a one-time playbook task or feature flag.
No production database was replaced and no iCloud import was performed.

The existing ZFS scrub independently passed: completed at 05:02 CEST after
2:02:04, 0 B repaired, zero errors, successful service exit and healthy pool.

## Backup artifact

Retained on Atlas:
`/zpool/backup/nextcloud-rehearsal-20261004T092635Z` (676 MiB observed).
Its host parent is restricted to admin, mode 0700; dump and manifest files were
created with umask 077. It contains sensitive application configuration and
database contents, not just test data. No plaintext secret was saved to Git.

- Complete application tree, including configuration, custom apps and themes;
  the overlaid data directory was copied separately.
- Complete dedicated files tree.
- PostgreSQL custom-format database dump, role definitions, image references,
  SHA-256 manifest and canary description.

Cron was stopped, maintenance enabled, and Nextcloud/ONLYOFFICE stopped while
the database dump and application/files copies were taken. Rsync checksum and
metadata comparisons passed while writers were stopped. Live services resumed
with maintenance off, and the cron timer resumed. Role definitions were captured
read-only immediately afterward when the isolated restore exposed the separate
`oc_admin` database role. Its saved password was subsequently verified against
the copied application configuration using SCRAM authentication. The recurring
procedure should capture both database and role dumps during the same pause.

## Isolated restoration

- Fresh rootless PostgreSQL using the exact production image digest, not the
  live database volume. Restored roles first, then the database with owners/ACLs.
- Copied application and files directories, using the matching Nextcloud image.
- Fresh, empty isolated Redis; cache contents are not a recovery requirement.
- One pod with `network=none`, no published ports and no live data bind mounts.
  Components communicate only through their shared loopback interface.
- Only the restored configuration was adjusted for loopback database/cache,
  localhost URLs and disabled mail. Production configuration was unchanged.
- No test cron or Office service was run. External connectivity and callbacks
  were impossible from this pod.

Checks passed:

1. Backup SHA-256 verification before restoration and again after cleanup.
2. PostgreSQL role/database restore with failure-on-error enabled.
3. Nextcloud 33.0.9 installed, maintenance off, no pending database upgrade.
4. Restored admin/fabio/chiara accounts and Famiglia permission mask 15.
5. The uniquely named Fabio canary existed both in files and the database index.
6. Authenticated HTTP WebDAV retrieved that canary from the restored instance;
   its SHA-256 matched the original uploaded contents.
7. The live canary remained unchanged and was then deleted through WebDAV.
8. Live Nextcloud, ONLYOFFICE and cron timer active; Office connection check
   passed. Cloud/Git/Music/Syncthing public HTTPS returned 200 with valid TLS.

Initial fixture failures established two prerequisites: wait for PostgreSQL's
final TCP listener, not the temporary initialization socket, and restore global
roles in addition to the database dump. Persistent Redis settings also require
a working isolated cache. Failed fixture pods were removed before retries.

After success, the final test pod and temporary restore directory were removed.
No test network, live rollback or pool snapshot destruction was needed.

## Limits and remaining work

This validates manual recovery from the current local application/database/files
copy, not a production-size recovery, RPO/RTO compliance, client resynchronization,
Office editing-session recovery, or extraction from Borg/offline USB. ONLYOFFICE's
own persistent service state was not part of this Nextcloud artifact.

The artifact has no dedicated automatic retention policy; do not call it the
recurring Nextcloud backup solution. Integrate a coordinated dump/copy or snapshot
procedure into recurring backups with locking, failure recovery, monitoring and
retention. Independently validate new offsite and offline versions before import.
Keep local/Vault recovery access independent of Nextcloud availability.

The procedure follows the required configuration/apps/files/themes/database scope
and maintenance pause described in the [Nextcloud backup guide](https://docs.nextcloud.com/server/33/admin_manual/maintenance/backup.html)
and tests restoration into a separate environment rather than applying the
[restore procedure](https://docs.nextcloud.com/server/33/admin_manual/maintenance/restore.html)
to production.

## Recurring integration and offsite recovery, later on 2026-10-04

The recurring preparation helper, system service, boot recovery and ordered
Borg/USB dependency drop-ins were deployed from Ansible. The existing snapshot
and backup jobs retain their lock, ownership, namespace, encryption and retention
policies. Two local verified bundles are the declared staging retention; this
supersedes the missing retention warning above for the managed bundle path only.
The earlier manually named rehearsal artifact remains separate and untouched.

Preparation published `20261004T094945Z-3294831`, then starting the actual Borg job
required a fresh preparation and published `20261004T095158Z-3303565`. Application
availability resumed before immutable copy/hash processing completed. The Borg
service successfully published `atlas-20261004T095255Z`, completed pruning and
compaction, and removed its source snapshot after exit.

The latter consistent bundle was extracted from that encrypted Hetzner archive,
not copied from the current local bundle. All SHA-256 checks passed. The extracted
application/files and PostgreSQL role/database dumps were recovered into a fresh
network-none pod with separate database/cache and matching image digests. It
reported installed Nextcloud 33.0.9 without pending upgrade. The three accounts,
Famiglia permissions and authenticated DAV PROPFIND for each account passed;
PostgreSQL used the saved role password with SCRAM on its isolated TCP listener.
The pod, extracted tree and its independent temporary Borg cache were removed.
Production services and the pool remained healthy.

Failure validation used sandboxed helper mocks for maintenance/dump errors: the
original failure code propagated, services/cron resumed, and state/partial files
were removed. Separate transient systemd fixtures verified that a failed ordered
requirement prevents its consumer from executing. These are fault-injection tests,
not production failures or proof of a full host-crash recovery. A real boot with
an interrupted preparation remains untested.

A third preparation published `20261004T100212Z-3366172`; exactly two managed
versions remained, with the oldest version pruned only after publication. Source
snapshots and persistent interruption markers were absent after success.

## Offline USB recovery, 2026-10-04

The operator unlocked the UUID-bound disk. Starting the USB job required fresh
bundle `20261004T100959Z-3415600` before the pool snapshot. USB version
`20261004T101101Z-3420114` passed its full checksum comparison and publication;
the service finished successfully at 18:41:29 Europe/Rome. Its recursive temporary
source snapshot was removed and LUKS closed.

After a second operator unlock, the published USB version was mounted read-only
with ext4 journal replay disabled. The consistent bundle was SHA-256 verified on
USB and again after extraction into a private temporary directory. A fresh
network-none pod restored PostgreSQL globals/database, application and files with
the recorded image digests, using a separate database and cache. Nextcloud 33.0.9
reported installed, maintenance off and no database upgrade required. All three
accounts, Famiglia permissions and authenticated DAV PROPFIND (HTTP 207) for
admin, fabio and chiara passed. No external network, published ports or live bind
mounts were present.

The USB was unmounted and LUKS closed. The test pod, extracted copy and path marker
were removed. No USB source snapshot remained; the pool was healthy and all live
Nextcloud, PostgreSQL, Redis, ONLYOFFICE and cron units were active. Production
data was not replaced. This is application recovery evidence for the current
small stack, not production-size RPO/RTO, client resynchronization or recovery of
unsaved ONLYOFFICE editing sessions. Client acceptance remains required before
family import.
