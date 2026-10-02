# iCloudPD: Aegis to Atlas

Atlas is the temporary ingestion host until Uranus. This is a **gated design
and staging path**, not authorization to stop Aegis or start a second downloader.
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
  25 GiB of unrelated data and is **not** the destination. The approved photo
  namespace is `/zpool/media/photobook`; its dataset is owned by `immich`
  (UID/GID 1100), mode 0770, and exported only to Aegis with `all_squash`
  to 1100. It currently has `acltype=off`. Neither the proposed
  `/zpool/media/photobook/iCloudPD` subtree nor `zpool/services/data/icloudpd`
  exists. The current ZFS mountpoint label is `unlabeled_t`, while Atlas has
  `nfs_export_all_ro/rw` enabled; the effect of the proposed container `:z`
  label on real NFS reads remains untested. Never rsync with `--delete` into
  Photobook or adopt its contents.

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
| Downloaded photos | `/zpool/media/photobook/iCloudPD`, a new managed subtree of the existing Aegis-only NFS dataset |
| Config, keyring, MFA cookies | `zpool/services/data/icloudpd` at `/zpool/services/data/icloudpd/config`, outside Photobook |
| Host service owner | `admin` rootless user manager; no rootful Quadlet or published port |
| Container identity | Entry process root in its user namespace; downloader UID/GID 1000 maps to host `admin` |
| Image | Digest-pinned `docker.io/boredazfcuk/icloudpd`, with no registry auto-update |
| SELinux | Private `:Z` config bind; shared `:z` photo bind for the NFS-visible subtree |
| Access | A POSIX ACL grants `admin` traversal, not listing or writing, of the existing Photobook root. The new subtree is `admin:immich`, setgid, with a default read/traverse ACL for `immich` (NFS UID 1100). Rootless-created files need not retain group 1100; the inherited named ACL is the intended read path. Real NFS reads still require runtime testing. |
| Sync policy | Daily interval; explicit directory/file modes 750/640; no iCloud deletion and no deletion of destination-only files |

The photo subtree receives a managed marker and the image's `.mounted` file.
An existing unmarked path is refused rather than taken over. The existing
Photobook root is not chowned or emptied. The rootless
Quadlet has no `[Install]` section and is not started while
`atlas_icloudpd_start=false`. Preparation itself is disabled by default and
requires `atlas_icloudpd_data_protection_verified=true`, which must only be
set after the actual first scrub and current backup health are checked. The
Apple ID is read from the existing Vault value only on explicit startup;
Ansible renders the private config with `no_log` and no diff. Aegis remains
unchanged throughout preparation.

The gating paths were checked on Atlas on 2026-10-02: the default
`--tags icloudpd --check --diff` run proposed zero changes; a preparation
request without the data-protection flag failed at the first assertion with
zero changes; and a startup request without preparation also failed at its
first assertion with zero changes. A simulated approved preparation completed
in check mode, showing only prospective dataset, ACL, directory, marker and
disabled-Quadlet changes. These checks do not authorize setting the flags.

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
**not** Apple authentication, a real download, NFS visibility, scheduled
operation, backup coverage, or recovery.

An additional 2026-10-02 test used only a disposable `/var/tmp` tree on Atlas:
an `immich:immich` mode-0770 parent granted `admin` execute-only ACL access,
and an `admin:immich` mode-2750 child had the proposed default ACL. The pinned
image, run rootless as downloader UID 1000 with no network, created a nested
directory and file. Their host IDs were `1000:100000`, not group 1100, but
the inherited ACL let host UID 1100 read/traverse them; it could not write to
the top-level photo directory, and `admin` could not list the parent. The
temporary tree and container were removed. This confirms local namespace/ACL
behavior, **not** an Aegis NFS read or behavior on the actual ZFS dataset.

Backup path review on 2026-10-02: the managed Borg and USB scripts snapshot
the pool recursively and bind every mounted child dataset, so both
`media/photobook` and the proposed `services/data/icloudpd` fall within their
declared source scope. Borg's runner switches to the dedicated `borg` account
with only `CAP_DAC_READ_SEARCH`; a read-only check using those exact `setpriv`
capability flags could traverse/read both Photobook and Archive, whereas plain
`sudo -u borg` could not. USB copies as root and preserves POSIX ACLs, but not
generic xattrs/SELinux labels. **This is scope and permission evidence, not a
completed backup or restore of iCloudPD data**, which does not exist yet.

## Validation and cutover gates

1. Verify the first completed monthly scrub from its service result, current
   pool/backup/alert health, free capacity, and a recent recoverable ZFS,
   Borg, and UUID-bound USB version. Do not treat active timers as proof.
   On 2026-10-02 the pool was healthy and Borg's last service result was a
   successful 09:31 CEST run, but `zfs-scrub-monthly@zpool.service` still had
   no execution timestamp; the timer's next run was 2026-10-04 03:00 CEST.
   Before changing the Aegis service, inspect the running container's actual
   `/home/user/iCloud` and `/home/root/iCloud` sizes with local root access,
   without copying or displaying filenames, credentials, or MFA material.
   If the overlay holds photos, include a deliberate, non-deleting export in
   the cutover plan; the empty host bind does not rule this out.
2. After that gate, set the three `atlas_icloudpd_*` flags deliberately in
   Atlas host vars. First prepare only (`prepare=true`,
   `data_protection_verified=true`, `start=false`) using `--tags icloudpd`.
   Check the new dataset, managed photo subtree, SELinux labels, Quadlet
   generation, and an inactive service. Do not modify Aegis.
3. Approve a separate start (`start=true`). Render the Vault-backed config,
   then run the interactive initialization locally or over a private SSH TTY
   as `admin`: `podman exec -it atlas-icloudpd sync-icloud.sh --Initialise`.
   Enter the password and MFA code **only into that session**, never into
   Ansible extra-vars, a chat, or a log. Initial synchronization may be large;
   inspect disk growth and Apple's response before allowing ongoing runs.
4. Verify that actual photos arrive only under the new subtree with the
   declared date structure, owner/mode and SELinux label. Compare file count,
   representative hashes/metadata, Aegis NFS read access as UID 1100, next
   scheduled result, and absence of unwanted deletions. The pre-existing
   25 GiB under Archive/Pictures must remain unchanged.
5. Verify recursive ZFS snapshot inclusion, a completed Borg archive, and a
   published USB version containing **both** photos and private state. Restore
   representative photos and the app config into an isolated 0700 directory;
   verify checksums, ownership, ACL/SELinux relabel procedure, and an isolated
   re-authentication/restore path. Never print or export live cookies.
6. Only after those tests and explicit cutover approval, stop/disable Aegis'
   `icloudpd.service` through a separate Aegis playbook change. Preserve its
   data/config for rollback; do not delete or restart stale ingestion blindly.
   Leave the Atlas `photobook` NFS export unchanged. Document the eventual
   Uranus handoff separately.

The current source state and lack of Aegis sudo access prevent declaring the
real migration validated. The first scrub has also not yet been observed.
