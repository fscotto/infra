# Isolated Atlas DR lab

This is a **scaled rehearsal**, not a substitute for a full-data restore. The
`atlas-dr-lab` libvirt VM on Ikaros was left **shut off** on 2026-09-30. Its
persistent volumes are in the default libvirt pool: the current 30 GiB OS
volume `atlas-dr-lab-os-rebuild2.qcow2`, the pre-rebuild OS volume
`atlas-dr-lab-os.qcow2`, and four independent 4 GiB
`atlas-dr-lab-data{1,2,3,4}.qcow2` volumes. The VM uses libvirt's `default`
NAT network (last DHCP address `192.168.122.168`), 2 vCPU, and 4 GiB RAM.
The data disks have `virtio-atlasdrdata{1,2,3,4}` serials. No physical disk or
production Atlas storage is attached. The VM has no autostart.

## Rebuild inputs and isolation

- Use Rocky's **9.8 GenericCloud Base x86_64** image
  `Rocky-9-GenericCloud-Base-9.8-20260525.0.x86_64.qcow2` from
  `https://download.rockylinux.org/pub/rocky/9.8/images/x86_64/`.
  Verify its `.CHECKSUM` file; the observed SHA-256 was
  `92c206cc6f790c61583247eefe87890f8828420662c17cacf247cec78ab4eec8`.
- Use a dedicated lab-only inventory merged **after** the repository
  inventory, and always `--limit atlas_dr_lab`. The temporary 2026-09-30
  inventory/playbook and logs are in `/tmp/atlas-dr-lab-image/`; copy a
  sanitized inventory to durable private storage before `/tmp` is cleared if
  the lab will be repeated. Never reuse `host_vars/atlas.yml`, production
  Vault secrets, or production disk by-id paths for the lab.
- The lab host belongs to `platform_rocky` and `atlas`. It uses `dradmin`
  (UID/GID 1000) with the operator's **public** SSH key and a random,
  unknown password hash, the libvirt DHCP address, pool `zpool`, mount root
  `/zpool`, the four `virtio-atlasdrdata*` by-id paths, a 1 GiB backup
  reservation, and `rocky_manage_openzfs_repo: true` with only `zfs` in
  `host_packages`. The following gates remain false: sharing, firewall,
  media stack, ZFS timers, Borg, USB, monitoring, and Prometheus pull.
  `atlas_manage_storage` is true. Set `atlas_create_pool: true` **only for the
  first disposable pool creation**, then set it false before any later run.
- A minimal lab playbook selects `atlas_dr_lab`, `become: true`, and the
  existing `packages_rocky` and `profile_atlas` roles. Use a separate
  `ANSIBLE_CONFIG` without the production Vault password script, and keep
  host-key checking on with a lab-specific known-hosts file. The 2026-09-30
  runs used `-i ansible/inventory/hosts.yml -i <lab-inventory.yml>` and
  `--limit atlas_dr_lab` throughout.

## Rehearsal and narrow checks

1. Before any pool operation, compare `virsh -c qemu:///system domblklist
   atlas-dr-lab` with the four intended qcow2 paths, and in the guest compare
   `/dev/disk/by-id/virtio-atlasdrdata*` with `lsblk`. Do not proceed if a
   physical disk or production identity appears.
2. For a first-time disposable build only, run the lab playbook with
   `--tags pool` and `atlas_create_pool: true`, then immediately set the gate
   false. Run the full lab playbook and check `zpool status -P zpool`,
   `zfs list -r zpool`, SELinux, and failed systemd units.
3. Write a non-sensitive canary under the lab `/zpool/archive` and snapshot
   it. Record the pool GUID and canary SHA-256. Export the lab pool cleanly,
   shut down the VM, and replace **only the OS volume** with a fresh verified
   Rocky image. Preserve all four data volumes. Reconfigure cloud-init for a
   new instance; the seed CD-ROM must use **SATA**. The SCSI seed attachment
   tried during this rehearsal was not detected by cloud-init and was
   replaced with a SATA attachment before proceeding.
4. On the new OS, apply `packages_rocky` to reinstall OpenZFS. First run
   `zpool import -d /dev/disk/by-id` **without importing**, compare GUID and
   vdev membership, then use ordinary `zpool import -d /dev/disk/by-id zpool`.
   Do not use `-f`, `-F`, `-X`, rollback, or pool creation.
5. Reapply `profile_atlas` with the lab gates and `atlas_create_pool: false`.
   Verify the canary, restored snapshot file in an empty temporary directory,
   dataset hierarchy, SELinux, and pool health. A second full playbook run
   should report `changed=0`. Remove temporary restored files and shut down
   the VM after testing.

The observed 2026-09-30 pool GUID was `8880368391795119587`; the canary
SHA-256 was `949701c7a95fadae1fddc21abe846c4312212dbfeb7477948f3188fc3ec34a78`.
The post-rebuild Ansible run succeeded, a repeat run reported `changed=0`,
12 datasets and the original snapshot were present, and the pool was healthy.
The snapshot-restored file matched content and basic metadata. See
[`atlas-recovery.md`](atlas-recovery.md) for the production runbook and limits.
