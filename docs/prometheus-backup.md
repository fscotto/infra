# Prometheus to Atlas backup pull

The playbook and both hosts have the dedicated identity, restricted SSH
access, helpers, and systemd units. A manual export, pull, and temporary
restore passed on 2026-09-30. The first scheduled export and pull passed on
2026-10-01. After NPM moved to its Quadlet, another manual export, pull, and
isolated restore passed on 2026-10-03. The first scheduled cycle after that
cutover is still pending. See `docs/prometheus-npm-quadlet.md`.

## Declared design

- Prometheus prepares a tar archive of Nginx Proxy Manager data and certificates,
  its active Quadlet and network definitions,
  and SSH/firewalld/WireGuard configuration. Gitea now runs on Atlas and is no
  longer included in new Prometheus exports. NPM access logs are excluded.
  The archive contains credentials, certificates, and the WireGuard private
  key: protect both copies accordingly.
- The approved consistency mode stops the NPM Quadlet for local tar creation
  at 02:00 Europe/Rome, then restarts it even if archiving fails. After the
  approved legacy cleanup, the helper requires the Quadlet active and has
  no Compose dependency. A manual test outside that window requires separate approval.
- Prometheus publishes the archive with its checksum as a versioned, read-only
  source under `/var/lib/prometheus-backup-export`. A locked service account
  has no sudo or supplementary groups. Its only authorized SSH key is forced
  through Rocky's `rrsync -ro`; root owns the key file and export directories,
  so the account cannot add an unrestricted key or change prepared data.
- Atlas generates and retains the private Ed25519 identity under
  `/etc/atlas-prometheus-pull`. Its pinned Prometheus host key came through
  the controller's already strict SSH trust; the observed fingerprint was
  `SHA256:rfedk7DHI9mLB3UHk/4F3HHlSIiswtCAFsAXvfh6iXk` on 2026-09-30.
  Atlas pulls only the prepared `current/` version, verifies SHA-256, tar
  readability, metadata, and source freshness, then publishes atomically
  below `/zpool/backup/hosts/prometheus/snapshots`. Long-term retention runs
  only after publication. A local `rrsync` fixture verified the in-tree
  `current` symlink. A live Atlas-to-Prometheus SSH test verified that the
  account could list only the prepared versions directory,
  cannot obtain a shell, and cannot write to the export. The key is restricted
  to `/var/lib/prometheus-backup-export/versions`, not the account's `.ssh`.
- Approved source preparation is 02:00 Europe/Rome, pull 03:00, three source
  versions, and 30 daily/8 weekly/12 monthly Atlas versions. The source
  timer is non-persistent to avoid an unexpected outage after a missed run.
  Atlas rejects a prepared source older than 24 hours.
- The Atlas pull joins the existing health monitor's timer/failure checks
  only when enabled. Its failure hook uses 45Drives Alerts; email delivery
  is not claimed. A failed source preparation should produce a stale-source
  pull failure, not a silently successful reuse of an old archive.

## Activation and verification

1. The user confirmed downtime/consistency mode, schedule, retention, and
   targeted configuration scope. Review the tar path list and exclusions
   against the actual containers.
2. The identity and units are deployed. Re-run the targeted
   check, confirm the Atlas public key remains only the restricted Prometheus
   account's key, and verify `sshd -T -C user=prometheus-backup,...` plus
   read-only SSH denial tests after any SSH configuration change.
3. During an agreed window, start the Prometheus export service manually.
   Confirm the active NPM service is healthy afterward, inspect the archive
   without exposing file contents, and verify the checksum/metadata.
4. Start the Atlas pull service manually. Confirm the SSH host pin, source
   freshness, checksum, tar listing, published `latest`, retention behavior,
   clean temporary directories, and healthy pool.
5. Independently restore the selected archive to an empty staging directory
   (never `/`) and compare NPM SQLite, data, active Quadlet files, certificates,
   permissions, and representative files. Historical pre-Gitea-cutover
   versions also include Gitea repositories; current versions do not. Test
   application startup only in an isolated environment or an approved restore
   window.
6. Both timers are enabled. Verify their calendars and the next actual run
   after any service-ownership change. A successful manual test is not proof
   of a later scheduled cycle.

Narrow static validation:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --syntax-check
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit prometheus,atlas \
  --tags prometheus_backup --check --diff
```

Do not run the export service as part of a routine playbook deployment. The
service restart and any restore/cutover require separate operator decisions.

On 2026-09-30 the initial targeted `--check --diff` run ended `changed=0`
with gates false. After enabling **implementation only**, a targeted real run
installed the identities and units; both timers were confirmed `disabled` and
`inactive`, the Compose stack stayed active, and the new account was locked
with no supplementary groups. No application was stopped.
The rendered shell helpers passed `bash -n` and ShellCheck; the retention
helper passed an isolated 400-version fixture. These static/isolated checks
were followed by live SSH, export, pull, and temporary restore checks.
Read-only preflight on 2026-09-30 found the Compose service active, all
declared source paths present, both timers inactive, and no prepared versions.
The source filesystem had about 6.0 GB free. Of the 2.1 GB NPM data tree,
2.1 GB was excluded access logs, so the expected archive is much smaller than
the raw tree size; capacity still needs verification after actual exports.
The manual export produced a 285,777,920-byte tar (273 MiB allocated at the
source), and Prometheus retained about 5.8 GB free. NPM and Gitea restarted;
both containers were running and their local HTTP endpoints returned 200.
Atlas pulled the same version, verified SHA-256, published `latest`, and kept
the pool healthy. A full extract to `/var/tmp` yielded 4,747 files; both
SQLite databases passed `PRAGMA integrity_check`, and one restored Gitea Git
repository passed `git fsck`. The temporary restore directory was removed.
This did not test application startup on an isolated host.

After these checks, Ansible enabled the Prometheus 02:00 Europe/Rome export
timer and Atlas 03:00 Europe/Rome pull timer. Their first scheduled run passed
on 2026-10-01; Atlas verified and published `20261001T000001Z` as `latest`.
Atlas' health monitor includes the pull timer.

On 2026-10-03 the stopped-source version `20261003T091009Z` was verified and
pulled before the NPM cutover. The post-cutover version `20261003T091633Z`
was exported by the Quadlet-aware helper, checksum-verified, pulled to Atlas,
and restored to an isolated temporary directory. NPM SQLite `quick_check`
passed with ten proxy hosts and six certificate records. The archive contains
both Quadlet definitions. A manifest of all 70 regular Let's Encrypt files
and 12 symlinks, including content hashes and link targets, matched the live
Prometheus tree. No private key or secret content was printed. The next
scheduled export/pull is still pending observation.

## Post-cleanup validation (2026-10-03)

The operator-approved removal of legacy data and Compose fallback also
removed those backup input paths and the obsolete Gitea mount dependency.
A separately approved export and Atlas pull published `20261003T112906Z`.
Both SHA-256 checks passed; an isolated SQLite restore passed `quick_check`
and contained ten proxy hosts. Both active Quadlet definitions were present;
retired paths were absent. Existing backup archives were not deleted by cleanup.
The first scheduled cycle after these changes remains unverified.
