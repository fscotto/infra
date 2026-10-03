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
  access to the Nextcloud-managed file namespace is provided.
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

## Gates before family data and full client acceptance

- Verify the first actual scrub and the outstanding protection checks.
- Public TLS, redirects, web login and WebDAV passed. Complete calendar/contact
  synchronization and Office editing/saving from a desktop.
- Test opening, editing and saving from the iPhone/iPad ONLYOFFICE app; mobile
  browser editing is not a requirement. No such client test is claimed yet.
- Private-space isolation and cross-user shared writes/deletes passed the public
  smoke test above; complete normal client acceptance as well.
- Integrate and test application-consistent database/files backups before import.
  The new datasets fall beneath existing recursive snapshot/backup scope, but
  that alone does not verify a new Borg/USB version or a consistent Nextcloud restore.
- For a consistent backup, coordinate pending Office saves, pause cron and writes,
  take a verified PostgreSQL dump and matching application/files snapshot, and
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
