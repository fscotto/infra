# Nextcloud on Atlas — design draft

Status: the empty stack was deployed on 2026-10-03, explicitly before the first
scrub. The operator configured DNS/NPM and authorized public cutover; public TLS,
DAV and cross-user file checks passed. Client editing/sync acceptance and consistent
backup/restore validation remain open before family data. iCloud import remains a
separate operation. See `docs/atlas-nextcloud.md` for observed runtime state.

## Confirmed requirements

- Three family members are the eventual scope; provision only two standard user
  accounts initially, `fabio` and `chiara`, with the third family user deferred.
  Each initial user has a private file space and no administrator privileges.
- Add a separate Nextcloud application administrator account named `admin`, for
  administration rather than daily document use. This is distinct from Atlas'
  host account of the same name; credentials must not be reused.
- 2FA is optional, not enforced for the accounts. Offer enrollment and recovery
  codes; encourage it for the administrator without silently imposing it.
- The three application accounts have been created in the empty deployment.
- No SMTP service is available. Initial deployment will not configure outbound
  email or provision a mail server. Email notifications and email-based password
  recovery are unavailable until SMTP is explicitly added. Document administrator-
  assisted recovery for standard users and a private host-side admin recovery
  procedure; do not expose a recovery endpoint or store plaintext passwords.
- Both initial users may add, edit and delete files in the shared `Famiglia`
  folder. This does not imply sharing personal calendars or contacts.
- No initial per-user Nextcloud storage quota for `fabio` or `chiara`. Available
  space is still bounded by the physical pool and any separately approved dataset
  limits; monitor capacity and do not describe this as unlimited physical storage.
- Files, calendars, contacts and Office document editing in the browser.
- iPhone/iPad, Windows and Linux clients.
- Migrate iCloud Drive files, calendars and contacts. The operator estimates
  approximately 50 GB of iCloud Drive files, excluding iCloudPD photos; this is
  an estimate, not a measured inventory. The files include a mix of Fabio's and
  Chiara's data. Migration is explicitly deferred to a separate later operation;
  initial deployment must not import iCloud files, calendars or contacts.
  Per-account mapping will be decided at migration time. Do not assume ongoing
  two-way synchronization with iCloud or extend this scope to iCloud Photos.
- ONLYOFFICE is the chosen editor: browser editing on desktop and the existing
  ONLYOFFICE app on iPhone/iPad. Mobile browser editing is not required.
- Temporary Atlas hosting, with eventual migration to Uranus.
- Completed one-time imports/migrations stay outside the steady-state playbook.

## Implemented architecture — public acceptance pending

- Nextcloud application with Files, Calendar, Contacts and an Office connector.
- PostgreSQL database and Redis for locking/cache; deployed versions and pinned
  image digests are declared in Atlas host vars and documented in the runbook.
- Dedicated ONLYOFFICE Docs service and its Nextcloud connector. Test real
  DOCX/XLSX/PPTX files in desktop browsers and opening/editing/saving through
  the mobile ONLYOFFICE app before acceptance. Community Edition is deployed;
  internal connector checks passed, but browser/mobile acceptance is still pending.
- Explicit Podman Quadlets managed by Ansible, preferably rootless like existing
  Atlas services, subject to image/user namespace/SELinux validation.
- Separate persistent application/configuration, user files, database and cache
  storage in the service namespace. Do not expose the managed Nextcloud data
  directory as a writable SMB share or let Syncthing modify it directly.
- Approved names: `cloud.fscotto.co` for Nextcloud and `office.fscotto.co` for
  ONLYOFFICE Docs. The operator configured DNS, certificates and NPM hosts;
  public endpoint and routing checks passed on 2026-10-03.
- Public HTTPS through Prometheus NPM and the existing Aegis gateway only.
  No public database/cache ports or directly exposed administrative interfaces.
- Office/Nextcloud callback routing, WebSockets, trusted proxies, JWT authentication
  and upload limits must be tested end to end before publication.
- Credentials remain in Vault; never enter passwords or private keys in chat.

## Office decision

The operator already uses ONLYOFFICE on mobile and desktop and selected it for
this project. Desktop browser editing will use ONLYOFFICE Docs integrated with
Nextcloud; mobile editing will use the existing ONLYOFFICE app. The limitation
on Community mobile web editors does not conflict with that requirement.
App integration, permissions, document fidelity and reliable saves still require
acceptance tests; the app is not treated as proof of server-side compatibility.

## Data protection and rollout gates

- The operator explicitly authorized this empty deployment before the first scrub.
  Close the data-protection checks before accepting live family data; this limited
  exception does not mark the scrub or recovery checks complete.
- Re-check free RAM/CPU/storage and existing workload before choosing limits or quotas.
- Design consistent backups covering configuration, custom apps/themes, user files
  and the database. ZFS snapshots alone do not establish application consistency.
- Define a coordinated maintenance/background-job pause and database dump/snapshot
  procedure for recurring backups, with failure cleanup and monitoring.
- Confirm ZFS/Borg/USB coverage and independently restore into an isolated environment
  before importing family data.
- Define deliberate upgrades and rollback boundaries; do not roll back a database
  independently of its matching application/data backup.
- Start with a test account and representative documents; migrate iCloud content
  explicitly only after client, sharing, Office and recovery tests pass.
- Plan Uranus transfer separately; do not add permanent one-time migration flags.

## Next decisions, one at a time

1. Validate desktop Office editing/saving, calendar/contact synchronization and
   mobile ONLYOFFICE app integration; public empty-stack cutover is verified.
2. Complete protection gates and application-consistent backup/recovery tests.
3. Plan the deferred iCloud migration when explicitly requested.

## Primary references

- [Nextcloud Office installation](https://docs.nextcloud.com/server/stable/admin_manual/office/installation.html)
- [ONLYOFFICE mobile web editor restrictions](https://helpcenter.onlyoffice.com/mobile/android/mobile-web-editors/overview.aspx)
- [Nextcloud backup requirements](https://docs.nextcloud.com/server/stable/admin_manual/maintenance/backup.html)
