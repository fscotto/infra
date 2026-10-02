# iCloudPD: Aegis to Atlas

Atlas is the temporary ingestion host until Uranus. Aegis iCloudPD and its
state were retired. Ansible declares Atlas storage, the rootless Quadlet,
and a private `icloudpd.conf` with the Apple ID from the existing Vault key.
The password, keyring and MFA cookies remain application-managed; initialization
is interactive.
Do not place cookies, keyring files, passwords, or the Apple ID in this document,
the repository, or a terminal transcript.

## Historical source and current destination (2026-10-02)

- Before retirement, Aegis' rootful `icloudpd.service` was active (no reported restarts, running
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
  `/zpool/archive/Pictures/iCloudPD` subtree. Both that subtree and
  `zpool/services/data/icloudpd` were created on 2026-10-02. Never rsync with `--delete` into
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
section, so Ansible does not start or enable it. Ansible renders a mode-0600
`icloudpd.conf` with `no_log` and no diff, but does not pull the image,
initialize MFA, or run a cutover task. The service was started manually and
will not start automatically after reboot under this design.

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

- Aegis retirement is complete: `icloudpd.service` is `not-found`/`inactive`,
  the rootful Quadlet and `/var/lib/icloudpd` are absent, and AdGuard is active.
  The temporary retirement tasks are no longer in the Aegis role. The Podman
  image cache may remain; it is not service data.
- Atlas storage and the `admin` Quadlet are deployed. The second Ansible
  run changed nothing and did not start the service; a later manual start
  generated the config. `/zpool/media/photobook` was unchanged.
- The image generated `/zpool/services/data/icloudpd/config/icloudpd.conf`
  on first start. Ansible replaced that default file with a private template
  using the Apple ID already in Vault. The operator must initialize password
  and MFA interactively; never put credentials or codes in the repository,
  chat, or Ansible extra-vars. The Quadlet has no automatic boot start;
  enablement requires a separate deliberate design change.
- After a real download, check folder structure, ownership, SELinux, SMB
  access, no unintended deletions, recursive ZFS snapshot inclusion, completed
  Borg and USB versions, and isolated restore of photos and private state.
  The first real scrub and measured recovery targets are still separate open
  items. Nothing here claims a completed Atlas ingestion or recoverable backup.

On 2026-10-02 Atlas storage and the inactive Quadlet were deployed; a second
Ansible run made zero changes. The generated service was inactive, and no
`icloudpd.conf` existed. Two interactive-sudo Aegis runs removed its service,
Quadlet and `/var/lib/icloudpd`, then cleared the failed-unit record left by a
SIGKILL during shutdown. Read-only verification found `LoadState=not-found`,
`ActiveState=inactive`, both paths absent, and AdGuard active.

On 2026-10-02 the operator requested the first manual start. The rootless
service stayed active, and the image generated `icloudpd.conf` under the
private config dataset. Its mode was tightened from 0644 to 0600. The generated
`apple_id` field is empty; no MFA or download is verified. The service has no
boot-time install target, so it is not configured for automatic startup.

The 2026-10-02 Atlas `icloudpd` run rendered the Vault-backed template without
printing its contents; the second run made zero changes. File owner is
`admin:admin`, mode 0600, and the Apple ID field is nonempty. The rootless
service remained active with zero restarts. Keyring initialization, cookie
creation and a real download are still unverified. The existing Vault variable
retains its historical `vault_aegis_icloudpd_apple_id` name; no password or
MFA code was added to Vault.

The attempted interactive initialization then lost its container. Diagnosis
found that the image launcher requires `traceroute` to pass its iCloud
reachability check. Rootless Podman without `NET_RAW` returned `Operation not
permitted` despite working Atlas/container DNS and host HTTPS. An isolated
container with only `CAP_NET_RAW` passed the same check. The Quadlet now grants
that single capability while keeping `NoNewPrivileges=true`; a manual restart
passed `traceroute`, and the app stayed running. Logs now show only the missing
keyring and wait for `--Initialise` again. The app expanded the generated config
on startup, so Ansible now seeds it only when absent and idempotently maintains
only its declared options. A second live Ansible run made zero changes. MFA,
actual ingestion, and backup/restore remain unverified.
