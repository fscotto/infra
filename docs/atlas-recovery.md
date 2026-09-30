# Atlas recovery runbook

This runbook is for a **replacement Rocky Linux 9 installation**, not a normal
playbook run. A scaled whole-OS rebuild with a disposable pool passed in an
isolated VM on 2026-09-30, but no production-size whole-host recovery has been
tested. The existing production pool must be imported, never created or
rewritten. The provisional targets are **RPO 24 hours**
and **RTO 72 hours**, for Archive and Atlas services alike. They are planning
objectives, not demonstrated recovery times. The manual USB cadence may leave
an older copy; a recent Borg archive is needed to meet the RPO after total
pool loss.

## Before an incident

- Keep an offline copy of the encrypted Ansible Vault, its unlock material,
  the exported Borg repository key, and the Borg passphrase. Do not store
  unlock material in this repository or in a recovery command line.
  On 2026-09-30 the operator confirmed these are available independently of
  Atlas and the Ansible controller; their usability has not been tested here.
- Keep the Atlas installation media and a reproducible checkout of this
  repository available independently of Atlas. Record the exact Git revision
  used for a successful deployment.
- Record the pool's current disk identities with `zpool status -P zpool` and
  `lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,UUID`. Compare these with
  `atlas_zpool_disks` before touching a replacement host. The `host_vars`
  values are historical identifiers, not evidence that a newly attached disk
  is the same device.
- Verify that the latest hourly/daily snapshots, Borg archive, and offline USB
  version exist and note their timestamps. A timer being enabled is not proof
  that a backup completed.

## Incident gate

1. Identify whether the fault is the OS disk, one or more pool disks, accidental
   deletion, or an unavailable host. Preserve failed media when possible.
2. Stop writes to affected services and capture the last known good backup
   timestamps. Do not run `zpool create`, `zpool destroy`, `zfs rollback`,
   `zpool import -F`, `zpool import -X`, `zpool import -f`, or disk formatting
   as a diagnostic shortcut.
3. Choose one recovery source below. Do not merge several sources into the
   production namespace without comparing their timestamps and content.

## Rebuild the OS and import the existing pool

1. Install Rocky Linux 9 on a **separate system disk**. Configure basic network,
   SSH, a temporary sudo administrator, SELinux enforcing, and the current
   OpenZFS kmod repository. Keep the pool drives untouched.
2. Run read-only identification: `lsblk -f`, `zpool import`, and
   `zpool import -d /dev/disk/by-id`. Check the pool GUID, vdev layout, and
   stable drive identities against the incident record. If any differ, stop.
3. Import only after matching the expected pool and host ownership. A pool
   cleanly exported from the old host can be imported with
   `zpool import -d /dev/disk/by-id zpool`. If it reports that the pool is
   active elsewhere or needs a rewind/force, stop and investigate rather than
   adding flags. Verify with `zpool status -v zpool`, `zfs list -r zpool`,
   `zfs get -r mountpoint,canmount zpool`, and `findmnt -R /zpool`.
4. Leave `atlas_create_pool: false`. Ensure `host_vars/atlas.yml` reflects the
   replacement host's actual SSH address and disk identities before running
   Ansible. Apply `ansible/site.yml --limit atlas` with the bootstrap admin
   connection override as documented in the Atlas setup section of README.
   This may start shares/services, so keep clients disconnected or services
   gated until data and permissions are verified.
5. Check `getenforce`, `zpool status -v zpool`, `systemctl --failed`, SSH,
   firewalld, Cockpit, NFS, SMB, and the backup/monitoring timers. Do not
   report recovery complete on the basis of Ansible success alone.

## Choose the data source

- **Local snapshot, pool intact:** inspect `zfs list -t snapshot -r zpool`.
  Mount/access the chosen snapshot read-only and copy selected files to an
  empty staging directory; compare content, owner, mode, mtime, and POSIX ACL.
  Move into the live namespace only after an operator-approved scope review.
  Do not use an automatic rollback: it can discard newer changes in the
  dataset and descendants.
- **Offline USB:** verify the configured LUKS and ext4 UUIDs from
  `host_vars/atlas.yml` before unlocking. Mount ext4 read-only with `ro,noload`,
  use only a published `atlas/latest` version, and restore to an empty staging
  directory. Compare checksums and metadata. The USB copy intentionally omits
  generic xattrs and SELinux labels; relabel only the restored destination.
  Never run the backup service to perform a restore.
- **Hetzner Borg:** use the dedicated pinned host key, repository path,
  offline exported recovery key, and Vault-backed passphrase. List archives
  and extract a selected archive into an empty staging directory, never the
  live `/zpool` tree. A repository check and sample restore were previously
  performed; that does not prove this incident's archive is complete. Compare
  content and metadata before publication. Avoid `borg break-lock` while any
  backup/check job may still be active.

After publishing restored files, run the explicit Ansible `restorecon` tag only
for the paths actually restored, for example:

```bash
ansible-playbook ansible/site.yml --limit atlas --tags restorecon \
  -e '{"atlas_restorecon_paths":["/zpool/archive"]}'
```

Then check ownership/ACLs, application-specific integrity, SMB/NFS client
access, backup service health, and `zpool status -v zpool`. Reconnect clients
only after these checks pass. Record the last recoverable timestamp (actual
RPO) and elapsed service outage (actual RTO) in the incident log.

## Scaled isolated rehearsal (2026-09-30)

The lab setup, repeatable checks, and preserved VM state are recorded in
[`atlas-dr-lab.md`](atlas-dr-lab.md).

On Ikaros, a local libvirt `atlas-dr-lab` VM used a 30 GiB Rocky 9.8 system
disk and four separate, disposable 4 GiB virtio data disks with stable
`/dev/disk/by-id` identities. The official Rocky cloud image matched its
published SHA-256. The lab inventory was separate from production, used a
fresh lab-only password hash and the operator's public SSH key, and disabled
sharing, Borg, USB backup, monitoring, media services, and the Prometheus pull.
No production disk, Vault secret, or production data was attached or copied.

1. The existing `packages_rocky` and `profile_atlas` roles installed OpenZFS,
   created a RAIDZ2 `zpool` through the explicit one-time pool gate, and built
   all 12 declared datasets with a lab-sized 1 GiB backup reservation. The
   pool creation gate was set false immediately afterward.
2. A 4 MiB canary file was written under the lab `archive` dataset and a ZFS
   snapshot created. The pool was cleanly exported and the VM shut down.
3. Only the system-disk volume was replaced by a fresh Rocky cloud image;
   the four virtio data volumes were retained. Ansible reinstalled OpenZFS.
   Read-only `zpool import -d /dev/disk/by-id` showed the expected RAIDZ2
   topology and pool GUID `8880368391795119587` before an ordinary import
   without `-f`, rewind, or rollback.
4. The imported pool was healthy. The canary SHA-256 matched its pre-rebuild
   value. `profile_atlas` completed against the imported pool and a second
   run reported `changed=0`. A file restored from the preserved snapshot into
   `/var/tmp` matched SHA-256, owner, group, mode, size, and mtime; the temporary
   copy was removed. Final checks found SELinux Enforcing, 12 datasets, the
   snapshot, no failed units, and a healthy pool. The VM was shut down while
   retaining its disposable volumes for a future rehearsal.

This proves the **sequence** for a cleanly exported, small pool and the tested
Ansible subset, not recovery duration or capacity at 2 TB. The earlier
2026-09-25 independent production ZFS/USB file restores and the earlier Borg
temporary-directory restore remain separate evidence. The VM did not restore
production USB/Borg archives, exercise services with production data, test an
unclean import, or prove the provisional RPO/RTO. Before relying on 24h/72h,
measure a representative full restore and service cutover in a suitably sized
future change window. Never use the production Atlas pool for a rehearsal.
