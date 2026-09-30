# Atlas SMB/NFS namespace decision

Decision date: 2026-09-30. Keep the current namespaces **separate**.

- `/zpool/archive` is the SMB3 `Archive` share for authorized Samba accounts.
- `/zpool/media/photobook` is the Aegis-only NFSv4 export, `all_squash`-mapped
  to UID/GID `1100`.
- No new dual-protocol namespace, broad export, group, or ACL model is needed.
  Existing permissions and client access remain unchanged.

The two paths serve different ownership and exposure needs. A common namespace
would expand the permissions design and require same-file SMB/NFS interoperability
testing without a present requirement. Revisit only when a specific workflow
needs both protocols on the same files; then decide UID/GID, group, POSIX ACL,
SELinux policy and client behavior before changing exports or permissions.

Read-only Atlas verification on 2026-09-30 confirmed that Samba `Archive` points
to `/zpool/archive`, NFS exports `/zpool/media/photobook` only to
`192.168.178.54` with `all_squash` and anonymous UID/GID `1100`, both datasets
are distinct, and `zpool` is healthy. No sharing configuration was changed.
