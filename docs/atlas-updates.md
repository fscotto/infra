# Atlas Rocky/OpenZFS update and reboot procedure (draft)

This is an operator-controlled maintenance procedure. The playbook does not
reboot Atlas, replace a pool device, or perform a pool feature upgrade.

## Preflight

1. Schedule an outage and confirm no Borg, USB, snapshot, scrub, or resilver
   job is active. A service in `activating` is still active; do not interrupt it.
2. Check `zpool status -v zpool` (including scrub status), `zfs list -r zpool`,
   `systemctl --failed`, and `systemctl list-timers --all`. Resolve pool errors
   first. Record current `uname -r`, `modinfo zfs | grep '^version:'`,
   `rpm -q kernel-core kmod-zfs zfs`, and the current boot entry.
3. Confirm a recent successful Borg archive and a usable snapshot. Confirm
   the latest published offline USB version and its physical availability;
   do not start a USB backup merely to satisfy a checklist without capacity,
   UUID, and operator checks. Record timestamps, not just timer state.
4. Ensure console/KVM or another independent recovery route is available.
   Check free space in `/boot` and the root filesystem. Review proposed DNF
   transactions before consenting to package changes.

## Change window

1. Stop client writes and quiesce stateful applications deliberately. Record
   which services were stopped; do not assume `ansible-playbook --check` does
   this. Avoid updating during a running scrub or backup.
2. Use `dnf upgrade --assumeno` first to review the kernel, `kmod-zfs`, `zfs`,
   and dependencies. Confirm a matching kmod will be available for the target
   kernel. If compatibility is uncertain, defer the update.
3. Apply the approved DNF transaction. Do not run `zpool upgrade` or enable
   new pool feature flags as part of ordinary OS maintenance; that can remove
   downgrade options. Preserve at least one known-good boot entry.
4. Reboot **manually** during the agreed outage. Ansible must not trigger it.

## Post-boot gate

1. Verify `uname -r`, `modinfo zfs`, `rpm -q kernel-core kmod-zfs zfs`,
   `zpool status -v zpool`, `zfs list -r zpool`, and `findmnt -R /zpool`.
2. Verify SELinux remains enforcing; inspect `systemctl --failed` and the
   journal for ZFS, mount, SSH, NFS, SMB, Cockpit, Podman, and backup errors.
3. Validate a read-only file listing through SMB and an NFS client access
   check before reopening writes. Check the rootless temporary services and
   all backup/monitoring timers. Run the Atlas health monitor in `--dry-run`
   mode, then a real check after inspection.
4. Re-enable clients and record versions, downtime, anomalies, and next
   successful snapshot/Borg run. A green boot alone is not a completed update.

## Failure response

If the new kernel cannot load ZFS, boot the previous known-good kernel from
the console and inspect package/kmod matching before trying another reboot.
Do not force-import, rewind, clear errors, or upgrade pool features to make a
failed OS update appear successful. Preserve logs and stop for a recovery
decision if the pool does not import cleanly.

The procedure-definition item is complete, but the procedure is **not yet
rehearsed** on a replacement host or during a real Atlas update. Record the
first controlled execution and its post-boot evidence separately.

Read-only preflight on 2026-09-30 observed kernel
`5.14.0-687.52.1.el9_8.x86_64`, ZFS module/package `2.2.11-1`, a healthy
`zpool`, enforcing SELinux, and no failed systemd units. This did not review
an upgrade transaction, stop services, or reboot the host.
