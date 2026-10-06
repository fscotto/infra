# Atlas Nextcloud — public empty-stack cutover

## Observed state, 2026-10-03

The operator explicitly approved an empty deployment before the first monthly
scrub, and subsequently authorized public cutover. No iCloud files, calendars
or contacts have been imported. Public empty-stack validation is not acceptance
of production data before the outstanding protection and recovery checks.

Ansible manages the steady state through `profile_atlas` and the host-local
`atlas_manage_nextcloud: true` declaration. No migration/import flags or helpers
were added. An actual repeat run returned `changed=0`, with no failures.

- Rootless `admin` Quadlets: Nextcloud 33.0.9, PostgreSQL 17.11, Redis 7.4.11 and
  ONLYOFFICE Docs Community 9.4.0.129 (image tag 9.4.0.1), on a dedicated network.
- Images are pinned by digest; Calendar 6.6.2, Contacts 8.9.1, ONLYOFFICE connector
  10.2.1 and Team Folders 21.0.9 archives are pinned by version and SHA-256.
- Dedicated ZFS namespace: `zpool/services/data/nextcloud`, with separate `app`,
  `files`, `database`, `cache` and `office` datasets. No writable SMB/Syncthing
  access to the Nextcloud-managed file namespace is provided. Existing Archive
  directories are exposed separately through local external storage (see below).
- The `admin` Nextcloud account is an application administrator, distinct from
  the host account. `fabio` and `chiara` are standard users in `famiglia`, each
  with no initial quota. Team folder `Famiglia` has unlimited quota and group
  permission mask 15 (read/create/update/delete, not additional re-sharing).
- Optional TOTP is available; 2FA is not enforced. SMTP is not configured.
- The five-minute user cron timer is active; a manual service run succeeded.
  Its `Type=oneshot` means a recurring short-lived job, not a one-time migration.
- Component memory ceilings are Nextcloud 2 GiB, ONLYOFFICE 4 GiB, PostgreSQL
  1 GiB and Redis 256 MiB; these are ceilings, not reserved memory or load-test results.

Nextcloud reported installed, no maintenance mode and no pending DB upgrade.
PostgreSQL was healthy; ONLYOFFICE `/healthcheck` returned `true`. The connector's
`onlyoffice:documentserver --check` succeeded using internal routing. JWT is
enabled and matches the dedicated secret; neither privileged containers nor
container-engine socket mounts are used.

NPM on Prometheus reached both upstreams through the Aegis gateway. Direct LAN
connections from Ikaros to 8080/8081 were blocked, and PostgreSQL/Redis had no
published host ports. Existing Git, Music and Syncthing HTTPS returned 200 with
valid TLS. NPM and its backup export timer stayed active; the pool remained healthy.

After operator DNS/NPM configuration, both public hostnames resolved to the VPS.
HTTPS and HTTP-to-HTTPS redirects passed with valid certificates. Both Proxy Hosts
were enabled with Force SSL and WebSocket support. Public Office health and its
browser API asset returned 200; the connector check also passed. Actual browser
editing/saving and native mobile client use remain operator acceptance tests.

Public session-based web login and authenticated WebDAV succeeded for admin,
fabio and chiara. CalDAV/CardDAV
discovery redirected to the DAV endpoint; Fabio's calendar/address-book collections
answered PROPFIND. A uniquely named private test file was inaccessible to Chiara.
Fabio created a test file in Famiglia; Chiara read, edited and deleted it, and Fabio
read the updated contents. All temporary test files were removed. These are HTTP
protocol checks, not device synchronization or large-upload acceptance evidence.

## Operator DNS and NPM configuration

Namecheap: add CNAMEs `cloud` and `office` to `fscotto.co`. Do not change the blog,
mail records or apex IP.

| NPM hostname | Scheme | Upstream | Port |
| --- | --- | --- | --- |
| cloud.fscotto.co | http | 192.168.178.55 | 8080 |
| office.fscotto.co | http | 192.168.178.55 | 8081 |

For each host, obtain a certificate for its hostname, enable Force SSL and
WebSocket support. Keep NPM administration loopback-only; do not expose port 81.
Nextcloud's declared upload ceiling is 2 GiB; align the proxy request-size and
timeout settings rather than claiming large uploads work before testing them.
Verify CalDAV/CardDAV `.well-known` redirects to `/remote.php/dav/` through NPM.
Never disable certificate verification to make Office work.

The browser-facing Office URL is `https://office.fscotto.co/`; server-side routes
use `http://atlas-onlyoffice/` and `http://atlas-nextcloud/` on the private network.
These internal routes require explicit local-address permission in the connector
and ONLYOFFICE. Metadata-address access remains disabled. Nextcloud trusts only
the declared Aegis address and rootless network gateway, not arbitrary proxies.

## Secrets and administration

Six unique secrets were generated into the existing encrypted `secrets/vault.yml`:
database, Redis, Office JWT and initial passwords for `admin`, `fabio`, `chiara`.
Use the local Vault editor to retrieve them; do not paste them in chat.
Account provisioning never resets an existing user's password. After a user
changes it, the initial Vault password is not necessarily their current password.
Database secret rotation needs a coordinated role-password update, not just an
edited initialization file. Image/app upgrades likewise require a deliberate window.

Host configuration lives below `/home/admin/.config/atlas-nextcloud` with a 0700
parent. Mounted individual secret files are readable by their container consumers,
but a different host user was verified unable to read them through the parent.
Nextcloud's managed PHP include inherits the live container SELinux category;
neither global relabeling nor disabling SELinux is used.

```bash
ansible-playbook ansible/site.yml --limit atlas --tags nextcloud --check --diff
ansible-playbook ansible/site.yml --limit atlas --tags nextcloud
```

Dry-run skips initial downloads, image pulls and runtime account/app commands;
it is not proof of an installed or healthy stack. The deployed repeat run is
the current idempotence evidence.

## Manual recovery evidence, 2026-10-04

The first monthly scrub completed successfully and was verified from both the
service result and pool scan (zero errors, 0 B repaired). A manual consistent
application/files copy and PostgreSQL dump were restored into a network-isolated
Nextcloud/PostgreSQL/Redis test pod. Account recovery, Famiglia permissions and
authenticated DAV retrieval of a checksum-matched canary passed. Live services
resumed normally; the test pod and restore workspace were removed.
See `atlas-nextcloud-recovery-test.md` for scope, retained artifact and limitations.

## Gates before family data and full client acceptance

- The first actual scrub passed on 2026-10-04; preserve the existing protection checks.
- Public TLS, redirects, web login and WebDAV passed. Complete calendar/contact
  synchronization and Office editing/saving from a desktop.
- Test opening, editing and saving from the iPhone/iPad ONLYOFFICE app; mobile
  browser editing is not a requirement. No such client test is claimed yet.
- Private-space isolation and cross-user shared writes/deletes passed the public
  smoke test above; complete normal client acceptance as well.
- The manual rehearsal and recurring integration passed, including recovery from
  a new encrypted Borg archive. Complete recovery from a new USB version before import.
  The new datasets fall beneath existing recursive snapshot/backup scope, but
  that alone does not verify a new Borg/USB version or recovery through those versions.
- For a consistent backup, coordinate pending Office saves, pause cron and writes,
  take verified PostgreSQL database and role dumps plus a matching application/files
  snapshot or quiesced copy, and
  resume services promptly even on failure. Extend recurring backup procedures,
  not the steady-state playbook with one-time migration tasks. Restore into an
  isolated environment using matching image/app versions, config, files and DB.
- Confirm encrypted Vault/recovery material is available offline. Without SMTP,
  recovery for standard accounts is administrator-assisted; a forgotten admin
  password can be reset through the private host-side `occ` CLI.
- Select versions deliberately for upgrades. Do not downgrade the application
  against an upgraded database; use matching tested backups for recovery.
- Future Uranus migration and iCloud import are separate, explicitly authorized
  operations. No source data deletion or automatic cross-system cutover is provided.

## Recurring consistent bundles

`atlas-nextcloud-backup.service` is now an ordered requirement of both
`atlas-borg-backup.service` and the operator-started `atlas-usb-backup.service`.
No additional backup timer is needed: the existing Borg schedule prepares a fresh
bundle before its pool snapshot, and a manual USB run does the same. Preparation
failure blocks the dependent job rather than silently using an old dump.

The helper checks the mounted datasets and healthy active application state,
serializes preparations and briefly pauses cron, Nextcloud and ONLYOFFICE. It
captures database plus global roles and a recursive Nextcloud-only ZFS snapshot.
Services resume before the longer immutable-file copy and checksum verification.
Active editing sessions are interrupted; only committed Nextcloud state is covered.
This does not claim preservation of unsaved ONLYOFFICE editing sessions.

Private bundles are published atomically under `/zpool/backup/nextcloud/versions`,
with a relative `latest` link. `atlas_nextcloud_backup_keep: 2` retains two local
verified versions, with hard links for unchanged files. Long-term Borg, USB and
ZFS policies are unchanged. A trap and `ExecStopPost` restore availability and
clean only this helper's named source snapshot/partial directory; root-private
persistent state permits boot recovery through the enabled recovery unit. Both
units have failure alerts and are included in the Atlas monitored failure units.
No automatic rollback, import, or repair of user application data is performed.

Validation:

```bash
ansible-playbook ansible/site.yml --limit atlas --tags nextcloud_backup,monitoring --check --diff
sudo systemctl start atlas-nextcloud-backup.service
sudo systemctl show atlas-nextcloud-backup.service -p Result -p ExecMainExitTimestamp
```

The second command briefly interrupts the applications and is an explicit manual
run of the recurring job, not a normal deployment side effect. The preparation
unit is not enabled as a boot backup; only interrupted-job recovery is enabled.
Do not stop a Borg/USB job, break its lock or unmount its source snapshot to run a test.

On 2026-10-04, both a new encrypted Borg archive and USB version
`20261004T101101Z-3420114` were independently extracted and their consistent
Nextcloud bundles restored in isolated containers. Checksums, account recovery,
Famiglia permissions and authenticated DAV passed. Temporary restore resources
were removed; USB was safely unmounted and LUKS closed. See
`docs/atlas-nextcloud-recovery-test.md` for exact evidence and limitations.
Desktop/mobile editing and synchronization acceptance remains open before import.


## Existing Archive storage (no import or duplicate originals)

The Atlas declaration exposes only these existing directories to the rootless
Nextcloud container, using shared SELinux `:z` labels:

| Nextcloud folder | Host directory | Access |
| --- | --- | --- |
| `Documenti` | `/zpool/archive/Documents` | Read/write |
| `Foto iCloud` | `/zpool/archive/Pictures/iCloudPD` | Read-only |

Both system mounts are restricted to the Nextcloud user `fabio` only; `chiara`
and the `famiglia` group have no access through these mounts.
External re-sharing is disabled. The photos bind is also read-only at container
level, independently of Nextcloud's mount option. iCloudPD remains the photo
writer. Neither directory is copied into the internal data dataset, and the
existing `Famiglia` team folder remains separate and untouched.

The Archive dataset enables persistent `acltype=posix` support; this does not
change pool features or vdev layout. Scoped ACLs grant the actual rootless-mapped web UID access to existing files and
inheritance on new directories/files. Document defaults retain host administrator
access to files created through Nextcloud; ownership is not changed recursively.
Symlinks are not followed when applying ACLs. Do not change Archive ownership or
apply private `:Z` relabeling to these shared paths.

The user `atlas-nextcloud-external-scan.timer` discovers external changes for only
these mounts and their explicitly allowed user: first after boot at 15 minutes, then one hour
after the previous scan finishes. Nextcloud also checks for external changes on
access. Indexing and previews are not duplicate originals; document versions,
trash, ZFS snapshots and backups may retain additional data intentionally.
Avoid simultaneously editing the same document through SMB and Nextcloud.

Archive originals retain their existing recursive ZFS/Borg/offline USB coverage.
The Nextcloud-only recovery bundle does **not** include these external originals:
a recovery must restore the corresponding Archive data as well as the application
and database. This change does not migrate iCloud Drive or remove anything there.


### Runtime validation, 2026-10-04

The mounts were applied on Atlas without importing originals. A disposable
application-level document create/read test reached the original bind directory;
the probe was deleted, including its trash entry. After the operator narrowed
access to Fabio only, fresh Nextcloud application checks confirmed Fabio can read
both mounts and create documents, while photo create/update/delete are denied.
Chiara cannot access either mount; the separate `Famiglia` team folder remains
available to both users. Container inspection independently confirmed the photo
bind is read-only. Public Nextcloud HTTPS returned 200 and the pool was healthy.
The targeted second Ansible run for mount applicability, options and discovery
unit returned `changed=0`, with no failures. This is focused idempotency evidence,
not a claim about a full Atlas playbook run.


### ONLYOFFICE landing-page restriction

An Ansible-managed, read-only Nginx include inside the ONLYOFFICE container returns
404 for `/`, `/welcome` and `/example` (including their descendants and
version-prefixed variants). The vendor editor, API, conversion, callbacks and
WebSocket routes remain unchanged. `EXAMPLE_ENABLED=false` keeps the demo service
inactive. No NPM Proxy Host edits or global CSP changes are required.

On 2026-10-04 the targeted deployment restarted only ONLYOFFICE. Nginx syntax and
Nextcloud's document-server check passed. Public root, welcome and example
requests returned 404; `/healthcheck` remained 200. This check does not replace
an authenticated browser edit/save test.


### Photos source-filter diagnosis — 2026-10-06

A recursive scan of `fabio/files/Foto iCloud` completed without errors:
1,615 folders and 11,699 files, already indexed. Authenticated DAV SEARCH returned
200 nested media results (the requested limit) for the sole `/Foto iCloud`
scope, both with and without date ordering, but zero results when the empty
`/Photos` scope was combined with it. The observed issue is the combined-source
search, not lack of recursive indexing.

The user preference `photosSourceFolders` was changed directly from
`["/Photos","/Foto iCloud"]` to `["/Foto iCloud"]`, after verifying no indexed
media under the personal Photos directory. No original files were moved or
modified, and no permanent one-time repair task was added to Ansible.
The diagnostic app password was revoked. Browser display confirmation remains
with the operator; this check does not establish mobile-gallery behavior.


### HEIC previews — 2026-10-06

The managed configuration include preserves the standard preview providers and
adds `OC\Preview\HEIC` for Apple HEIC/HEIF images. The pinned app image
already provides Imagick with HEIC/HEIF decoding. Ansible deployment succeeded;
a real indexed HEIC generated a 512×512 preview successfully, and the original
file SHA-256 was unchanged. Nextcloud, ONLYOFFICE and cron remained active.
No bulk conversion or full-library preview generation was performed.
New previews are generated on demand; browser/mobile display remains an
operator acceptance check.
