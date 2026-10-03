# fscotto.co domain transition

## Observed state (2026-10-03)

Namecheap remains the DNS provider. The operator moved GitHub Pages to
`blog.fscotto.co` in `fscotto/fscotto.github.io`, aligned Hugo and Pages
settings, and changed the apex A record to `179.237.102.172`. The blog
remains a CNAME to `fscotto.github.io`; mail records were left unchanged.
A new Hugo deployment and cache clearing resolved the initial stale DNS
and generated URLs. Blog HTTPS returned 200 with valid TLS.

The `git`, `music` and `syncthing` subdomains are CNAMEs to `fscotto.co`.
The operator added NPM Proxy Hosts with certificates, WebSocket support
and Force SSL:

| Hostname | HTTP upstream |
| --- | --- |
| git.fscotto.co | 192.168.178.55:3000 |
| music.fscotto.co | 192.168.178.55:4533 |
| syncthing.fscotto.co | 192.168.178.55:8384 |

All three redirected HTTP to HTTPS and returned final HTTPS 200 with valid
TLS. Only the Syncthing GUI uses NPM; native synchronization is unchanged.
NPM administration remains loopback-only on port 81 via SSH tunnel.

## Gitea canonical hostname

Atlas declares `atlas_gitea_public_domain: git.fscotto.co`. Ansible manages
only `[server] DOMAIN`, `ROOT_URL` and `SSH_DOMAIN` in the existing private
app.ini, preserving unrelated settings and mode 0600. Private configuration
backups are created; diffs and secret-bearing results are suppressed.
Only Gitea restarts when these fields change; a repeat run changed nothing.

HTTPS uses `https://git.fscotto.co/`; public SSH remains TCP/2222.
Agent read-only checks returned the same HEAD from `fscotto/infra.git`
over HTTPS and authenticated SSH. SSH host identity was checked against
the already-trusted old endpoint key. No test push or user-authenticated
web login was performed by the agent.

```bash
ansible-playbook ansible/site.yml --limit atlas --tags gitea_public_domain --check --diff
```

Client remotes do not update automatically. Update them deliberately after
checking repository paths; integrations and webhooks are separate operations.
For the verified infrastructure repository only:

```bash
git remote set-url origin ssh://git@git.fscotto.co:2222/fscotto/infra.git
```

Do not copy this path into unrelated clones. Verify Gitea's known SSH key
before accepting the new hostname's identity.

## Local DuckDNS retirement

DuckDNS support has been removed entirely from the server profile. On 2026-10-03 the explicit
Ansible cleanup removed the five-minute rocky cron entry and the private
`~/duckdns` directory containing only `duck.sh` and `duck.log`. The temporary
cleanup tasks and flag were subsequently removed from the playbook at the
operator's request. The updater provisioning tasks, template, variables and
enablement flag were also removed; there is no retained opt-in support.
The external DuckDNS name, Vault token, disabled NPM hosts and certificates
remain untouched for a separate future decision.
Before removing the temporary cleanup tasks, the repeat cleanup changed nothing.
The cron table had no remaining entries, NPM and the export timer were active,
and NPM administration still listened only on `127.0.0.1:81`.

## Operator-confirmed transition completion

On 2026-10-03 the operator confirmed completion of:

- Web login on the new Gitea hostname.
- Updates to remaining Git remotes, webhooks and integrations.
- Removal of obsolete DuckDNS NPM Proxy Hosts, unused certificates and the old upstream override.
- Review and removal of completed one-time procedures from the playbook.

These are operator confirmations, not new agent runtime checks or a test push.
At the earlier inspection the three old DuckDNS Proxy Hosts were disabled,
not deleted; that observation predates the confirmed cleanup. Existing backup
archives remain preserved. DNS/Pages/NPM changes were operator actions;
the Gitea application configuration change was deployed through Ansible.
