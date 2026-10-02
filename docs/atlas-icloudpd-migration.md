# iCloudPD: Aegis to Atlas

Atlas is the temporary ingestion host until Uranus. The operator authorized
retiring Aegis iCloudPD, including its data and MFA state, although Atlas is
not configured or started yet. Ansible declares only Atlas storage and an
inactive rootless Quadlet; it does not manage Apple configuration or MFA.
Do not place cookies, keyring files, passwords, or the Apple ID in this document,
the repository, or a terminal transcript.

## Observed source and destination (2026-10-02)

- Aegis' rootful `icloudpd.service` is active (no reported restarts, running
  since 2026-07-25), but its declared data bind `/var/lib/icloudpd/data`
  has **zero top-level entries** and is 4 KiB as observed on 2026-10-02.
  Its persistent config has two top-level entries. `pi` cannot run passwordless
  sudo, so the container's internal filesystem and root-only state have **not**
  been audited. Do not conclude there are no photos to preserve: they could be
  inside the container overlay because the declared bind targets the wrong
  home. The current
  Quadlet mounts that data directory at `/home/root/iCloud`; the image's
  documented default is `/home/user/iCloud` with its default `user=user`.
- The non-secret `folder_structure` value in the persisted Aegis config is a
  systemd generator path, **not** `{:%Y/%m/%d}`. The Quadlet passes percent
  characters in `Environment=` without systemd escaping; that is the likely
  cause. A running unit therefore does not prove that Aegis ingests photos.
  Do not copy this config or assume that its MFA state is usable on Atlas.
- Atlas' `zpool` is healthy. `/zpool/archive/Pictures` already contains about
  25 GiB of unrelated data; iCloudPD gets only a new managed
  `/zpool/archive/Pictures/iCloudPD` subtree. Neither that subtree nor
  `zpool/services/data/icloudpd` exists. Never rsync with `--delete` into
  Pictures or adopt its existing contents. `/zpool/media/photobook` is reserved
  for Immich and remains untouched, including its Aegis-only NFS export.

The upstream image documents `/config/icloudpd.conf` as its primary
configuration (environment configuration is deprecated), an exact
`/home/${user}/iCloud/.mounted` failsafe, and an interactive `--Initialise`
step for keyring and MFA cookies. The configuration must use the same download
path, user/UID, and folder format as the bind mounts. References:
[image configuration](https://github.com/boredazfcuk/docker-icloudpd/blob/master/CONFIGURATION.md),
[Podman user namespaces](https://docs.podman.io/en/latest/markdown/podman-pod.unit.5.html).

## Declared Atlas target

| Item | Location or policy |
| --- | --- |
| Downloaded photos | `/zpool/archive/Pictures/iCloudPD`, a new managed subtree of the SMB `Archive` dataset |
| Config, keyring, MFA cookies | `zpool/services/data/icloudpd` at `/zpool/services/data/icloudpd/config`, outside Archive |
| Host service owner | `admin` rootless user manager; no rootful Quadlet or published port |
| Container identity | Entry process root in its user namespace; downloader UID/GID 1000 maps to host `admin` |
| Image | Digest-pinned `docker.io/boredazfcuk/icloudpd`, with no registry auto-update |
| SELinux | Private `:Z` config bind; shared `:z` photo bind because Archive is also exposed through SMB and used by Syncthing. The label and SMB behavior require runtime testing. |
| Access | The new subtree is `admin:admin` mode 0750. No Photobook ownership, ACL, or export changes. |
| Sync policy | Daily interval; explicit directory/file modes 750/640; no iCloud deletion and no deletion of destination-only files |

The photo subtree receives a managed marker and the image's `.mounted` file.
An existing unmarked path is refused rather than taken over. The existing
Pictures tree is not chowned or emptied. The Quadlet has no `[Install]`
section, so Ansible does not start or enable it. Ansible does not render
`icloudpd.conf`, pull the image, initialize MFA, or run a cutover task. The
operator will configure and start it separately. The service will not start
automatically after reboot under this design.

The previous gated check-mode tests and isolated Quadlet-generator test proved
only the proposed layout; they predate the simplified declarative role. They
were not a production deployment or an authentication test.

## Evidence already gathered without production writes

The digest-pinned image was pulled into **admin's** Atlas Podman store. An
isolated `/var/tmp` test ran with no network, a fake Apple ID, private temporary
config/photo mounts, `keep-id:uid=1000,gid=1000`, and no new privileges. Both
container root and UID 1000 wrote to the mounts; UID
1000's files mapped to host `admin`. A short-lived container remained running,
retained the intended `/home/user/iCloud` and literal `{:%Y/%m/%d}` config,
and saw an admin-owned `.mounted` marker. The container and temporary files
were removed. A second isolated test showed that dropping **all** container
capabilities prevents its root entrypoint from reading an admin-owned 0600
config; with the default rootless user-namespace capabilities it could read
and write that file. The Quadlet retains `NoNewPrivileges=true` but does not
drop every capability. This proves only the container layout and namespace mapping,
**not** Apple authentication, a real download, SMB visibility, scheduled
operation, backup coverage, or recovery.

The earlier disposable Photobook ACL test is superseded by the operator's
clarification that Photobook belongs to Immich. It is not evidence for the
current Archive destination, and the proposed Photobook ACL change was never
deployed.

Backup path review on 2026-10-02: the managed Borg and USB scripts snapshot
the pool recursively and bind every mounted child dataset, so both
`archive` and the proposed `services/data/icloudpd` fall within their
declared source scope. Borg's runner switches to the dedicated `borg` account
with only `CAP_DAC_READ_SEARCH`; a read-only check using those exact `setpriv`
capability flags could traverse/read Archive, whereas plain
`sudo -u borg` could not. USB copies as root and preserves POSIX ACLs, but not
generic xattrs/SELinux labels. **This is scope and permission evidence, not a
completed backup or restore of iCloudPD data**, which does not exist yet.

## Remaining validation

- Apply the Aegis desired-absent role with interactive sudo (`-K`) and verify
  `icloudpd.service` stopped/disabled, the rootful Quadlet absent, and
  `/var/lib/icloudpd` absent. The operator explicitly authorized deletion of
  this data and MFA state despite the uninspected container overlay. Ansible
  refuses deletion if a mount exists under that path. The Podman image cache
  may remain; it is not service data.
- Apply the Atlas `icloudpd` tag to create only the state dataset, photo
  subtree, marker, and inactive `admin` Quadlet. Confirm no service/container
  was started and that `/zpool/media/photobook` was unchanged.
- The operator must write `/zpool/services/data/icloudpd/config/icloudpd.conf`
  privately, handle Apple authentication/MFA, and start the generated user
  service manually. Do not put credentials or MFA codes in Ansible extra-vars,
  the repository, chat, or logs. The inactive Quadlet has no automatic boot
  start; enablement requires a separate deliberate design change.
- After a real download, check folder structure, ownership, SELinux, SMB
  access, no unintended deletions, recursive ZFS snapshot inclusion, completed
  Borg and USB versions, and isolated restore of photos and private state.
  The first real scrub and measured recovery targets are still separate open
  items. Nothing here claims a completed Atlas ingestion or recoverable backup.

On 2026-10-02 Atlas storage and the inactive Quadlet were deployed; a second
Ansible run made zero changes. The generated service was inactive, and no
`icloudpd.conf` existed. At the last Aegis read-only inspection its service
was still running and non-interactive sudo was unavailable. The unassisted Ansible dry-run failed at
fact gathering with `Missing sudo password` before making changes.
