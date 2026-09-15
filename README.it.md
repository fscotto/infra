# Infra — Personal Infrastructure as Code

> **English version:** [README.md](README.md)

Questo repository contiene la configurazione **Infrastructure as Code (IaC)** utilizzata per gestire e mantenere allineate diverse macchine personali tramite **Ansible**.

L'obiettivo è avere **una singola fonte di verità** per:

- configurazione delle macchine
- pacchetti installati
- servizi di sistema
- configurazioni utente (dotfiles)

Il repository consente di gestire più sistemi operativi e profili macchina mantenendo una struttura modulare, riproducibile e idempotente.

---

# Architettura del progetto

```text
infra/
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml
│   ├── inventory/
│   │   ├── hosts.yml
│   │   ├── group_vars/
│   │   └── host_vars/
│   ├── templates/
│   └── roles/
│
├── dotfiles/
│   ├── common/
│   ├── desktop/
│   ├── fedora/
│   ├── server/
│   ├── workstation/
│   ├── workstation_dev_wsl/
│   └── nymph/
│
├── scripts/
├── secrets/
├── README.md
└── README.it.md
```

Il repository è diviso in due componenti principali:

| Componente | Scopo                                  |
| ---------- | -------------------------------------- |
| ansible    | provisioning e configurazione macchine |
| dotfiles   | configurazioni utente versionate       |

---

# Macchine gestite

Il repository modella attualmente host Fedora/GNOME, una workstation Fedora WSL, un server Rocky
Linux 9 e un NAS Rocky Linux 9. La composizione resta separata in assi indipendenti:

```text
common user environment
+ host-specific platform
+ role-specific software
+ independently selectable desktop
+ host hardware overrides
```

Matrice target:

| Host         | Platform | Role                 | Desktop |
| ------------ | -------- | -------------------- | ------- |
| ikaros       | Fedora   | Personal workstation | GNOME   |
| nymph        | Fedora   | Desktop laptop       | GNOME   |
| deadalus     | Fedora WSL | Workstation dev    | —       |
| prometheus   | Rocky Linux | Server            | —       |
| atlas        | Rocky Linux | NAS               | —       |

Regola operativa:

```text
ikaros must be boring
nymph is allowed to break
```

`ikaros` usa Fedora Workstation/GNOME come desktop personale stabile; `nymph` usa lo stesso
target Fedora Workstation/GNOME come laptop. I gruppi legacy `void` e `desktop` restano alias di
compatibilita per eventuali host Void futuri mentre i nuovi assi sono
`platform_*`, `role_*` e `desktop_*`.

Nota sullo stato attuale del playbook principale:

- `ansible/site.yml` applica oggi in automatico Fedora/GNOME su `ikaros` e `nymph`
- `ansible/site.yml` applica il profilo Fedora WSL alla workstation `deadalus`
- `ansible/site.yml` applica il profilo server Rocky a `prometheus` con DNF, systemd, dotfiles server e firewalld
- `ansible/site.yml` applica il profilo NAS Rocky su `atlas` tramite SSH remoto

## Desktop

Target operativi:

- `ikaros`: Fedora Workstation + GNOME, desktop personale stabile/floating.
- `nymph`: Fedora Workstation + GNOME, laptop desktop con dotfiles desktop condivisi e GNOME lasciato al default Fedora.

Il profilo Void desktop resta disponibile come modello riutilizzabile per host
futuri e usa esclusivamente `desktop_environment: minimal`: Sway e il default,
mentre Niri si seleziona con il gruppo `desktop_niri`. GNOME e disponibile solo
sui target Fedora tramite `desktop_gnome`.

Lo stato attuale del profilo desktop include, tra le altre cose:

- dotfiles comuni e desktop
- sessioni Sway e Niri per eventuali host Void in modalita `minimal`
- `emptty` con default host-specific in modalita `minimal` e session file Wayland per `sway`
- pacchetti Void Linux e servizi runit; le liste pacchetti Void desktop sono separate per criterio:
  - `void_packages_base` per il runtime sistema (init, kernel, audio core, networking, firewall, hw daemons)
  - `desktop_common_packages` per l'infrastruttura condivisa
  - `desktop_minimal_packages` per applicazioni GTK e `emptty`
  - `desktop_sway_packages` per i binari specifici della sessione Sway
- `turnstile` per i servizi utente Void, incluso `ssh-agent`
- `ssh-agent` con socket stabile condiviso tra shell e SSH in `~/.local/state/ssh-agent/socket`
- Emacs usa una sola configurazione orientata a Org e authoring, condivisa da desktop Fedora/GNOME e workstation; Vim resta l'editor di sviluppo
- `tmux` con plugin gestiti da TPM al bootstrap del profilo desktop
- Flatpak con remoto Flathub
- GNOME Keyring e `udiskie` nella modalita minimale
- multi-monitor Void: sotto Sway è gestito da `kanshi`

---

## Workstation

La workstation `deadalus` usa Fedora in WSL sulla macchina Windows omonima, senza runtime Flatpak o Snap.
Il profilo è pensato per sviluppo e lavoro.

Nel modello Ansible usato qui, un singolo inventory host puo appartenere intenzionalmente a piu gruppi e quindi ricevere piu play nello stesso run: l'associazione non e `1 host = 1 play`, ma `host + gruppi = layering finale`.

Il profilo workstation e agganciato al playbook principale tramite:

- layer dev Fedora
- layer WSL dedicato per sviluppo con `systemd`

Lo stato attuale del profilo workstation include:

- installazione pacchetti base Fedora via dnf
- installazione e configurazione di Docker dal repository ufficiale
- installazione di Mise dal COPR ufficiale con JDK Eclipse Temurin Java 11 fissato
- gestione dei dotfiles workstation e rendering dei template dev condivisi
- preparazione di Fedora WSL con `systemd` per il toolchain di sviluppo
- attivazione del firewall `firewalld` sui target Fedora che dichiarano regole host-specifiche

Workflow WSL previsto:

1. avviare Fedora WSL almeno una volta e completare la creazione dell'utente Linux
2. installare Ansible dentro la distribuzione WSL
3. lanciare il playbook dalla distribuzione su `deadalus` per configurare l'ambiente dev locale
4. usare VS Code con le estensioni Remote (`WSL`, `SSH`, `Dev Containers`) dal lato Windows

Le applicazioni Windows sono installate e gestite manualmente; il profilo WSL non installa componenti di remoting Python per esse.

---

## Server

Sistema operativo:

- Rocky Linux 9

Configurazione:

- nessun ambiente grafico

Macchina:

- `prometheus`

Profilo orientato a servizi server e gestione di dotfiles dedicati.

Lo stato attuale del profilo server include:

- installazione pacchetti Rocky via DNF, EPEL e CRB
- installazione di Podman e podman-compose
- abilitazione dei servizi systemd dichiarati in inventory/group vars
- copia dei dotfiles server e rendering del `docker-compose.yml` per Nginx Proxy Manager e Gitea,
  piu l'unita `podman-compose-server` (attivazione manuale)
- attivazione di firewalld con SSH, Cockpit (`9090/tcp`), HTTP e HTTPS abilitati
- Syncthing escluso dal profilo server Rocky

Il Compose desiderato su Prometheus non include piu Navidrome ne il database PostgreSQL obsoleto.
Navidrome e Syncthing appartengono ad Atlas; Navidrome ufficiale usa invece SQLite. Il profilo non
arresta o rimuove automaticamente eventuali container legacy e non elimina `/opt/postgres/data`.

Nginx Proxy Manager pubblica solo `80/tcp` e `443/tcp`; la sua interfaccia di amministrazione e
associata a `127.0.0.1:81` ed e raggiungibile da Ikaros o Nymph con l'alias Bash `npm-tunnel`.
Nextcloud resta disabilitato e il profilo non crea directory `/srv/nextcloud`.

La fase 1 su Atlas non modifica questo deployment NPM ne i suoi dati persistenti. Dopo aver attivato
WireGuard e i servizi Atlas, configurare i proxy host NPM correnti con upstream Navidrome
`http://10.0.0.2:4533` e upstream per la GUI Syncthing `http://10.0.0.2:8384`. Solo la GUI web di
Syncthing usa NPM; il traffico di sincronizzazione resta sulle porte native pubblicate esplicitamente solo
sull'indirizzo WireGuard di Atlas. Configurare l'autenticazione Syncthing e una policy di accesso NPM adeguata prima di pubblicare la GUI.

### DuckDNS

`profile_server` genera `~/duckdns/duck.sh` con permessi `0700`, mantenendo il percorso dello
script e `duck.log`. Definire `server_duckdns_domain` negli host vars del server e salvare il
**nuovo token rigenerato** in `vault_duckdns_token`, nel Vault cifrato `secrets/vault.yml`
(`ansible-vault edit secrets/vault.yml`) oppure negli override non versionati `secrets/vault.local.yml`.
Non committare lo script generato e non passare il token sulla riga di comando. Il rendering
nasconde output e diff sensibili; lo script verifica TLS e passa il token a curl tramite stdin.
Il playbook non esegue lo script e non modifica la sua schedulazione esterna.

```bash
ansible-playbook ansible/site.yml --limit prometheus --tags duckdns --check --diff
ansible-playbook ansible/site.yml --limit prometheus --tags duckdns
```

La cancellazione dalla cronologia non revoca il token: rigenerarlo sul pannello DuckDNS.
Dopo la bonifica, riclonare gli altri checkout senza unire nuovamente la vecchia storia;
salvare separatamente eventuali modifiche non committate senza copiare segreti.

### Migrazione dati

Dopo il provisioning Rocky, eseguire `scripts/migrate_prometheus_data.sh` **sul server Ubuntu
sorgente**. Lo script usa rsync, e in dry-run di default; richiede `--quiesce-source --execute` per
fermare lo stack sorgente e copiare in modo consistente soltanto i dati di Nginx Proxy Manager e
Gitea. Non sposta Navidrome o Syncthing, non avvia container, non cancella dati e non esegue il
cutover.

Utente del profilo server:

- il profilo usa `server_username`, `server_user_group` e `server_user_home` definiti in `ansible/inventory/group_vars/server.yml`
- per default `server_username` eredita `username`, ma puo essere sovrascritto per tutti gli host server via inventory oppure a runtime con extra vars
- esempio override da CLI:

```bash
ansible-playbook ansible/site.yml --limit prometheus -e server_username=myuser
```

- se necessario puoi passare anche:

```bash
ansible-playbook ansible/site.yml --limit prometheus -e server_username=myuser -e server_user_group=mygroup -e server_user_home=/srv/myuser
```

---

## NAS

`atlas` e un NAS Rocky Linux 9 raggiunto tramite SSH. Normalmente il pool ZFS esiste gia e il profilo
gestisce solo i dataset figli. Un bootstrap RAIDZ2 una tantum e disponibile solo con conferma esplicita
(`atlas_create_pool=true`) e quattro percorsi reali e verificati `/dev/disk/by-id/...` in
`atlas_zpool_disks`. Non partiziona, forza, distrugge, esegue rollback o modifica il layout vdev di un
pool esistente. I client Linux usano NFSv4, quelli Windows/WSL SMB; entrambi restano limitati alla LAN
configurata.

Per il primo avvio fornire `vault_atlas_authorized_ssh_keys`, `vault_atlas_admin_password_hash`,
`vault_atlas_samba_password` e `vault_atlas_immich_db_password`. Eseguire il bootstrap tramite
l'amministratore esistente:

```bash
ansible-playbook ansible/site.yml --limit atlas \
  -e atlas_connection_username=<existing-admin>
```

`vault_atlas_admin_password_hash` deve essere un hash compatibile con `/etc/shadow`, non una
password Cockpit in chiaro. Le esecuzioni successive usano `atlas_admin_username`. Atlas dichiara
abilitati storage, condivisioni e regole firewall LAN. Prima della prima applicazione verificare pool e
mountpoint esistenti, subnet LAN e zona firewalld attiva. `atlas_manage_media_stack` resta disabilitato
finche non saranno validati `/dev/dri`, i percorsi dei container e il segreto del database Immich.

Con la gestione storage attiva, Atlas crea l'intera gerarchia sotto il pool `zpool` esistente o creato esplicitamente:
`work`, `archive`, `archive/app_data`, i dataset applicativi separati
`archive/app_data/navidrome` e `archive/app_data/syncthing`, `media`, `media/music`,
`media/photobook`, `backups`, `backups/services` e `backup_prometheus`. I dataset applicativi e
di archivio usano `zstd`; media, Syncthing e backup dei servizi usano `lz4`;
`backups/services` mantiene inoltre una `refreservation` di `500G`.
Atlas impone SELinux targeted in modo persistente e segnala, senza avviarlo, l’eventuale reboot necessario per attivarlo. Assegna esplicitamente l’interfaccia LAN primaria alla zona firewalld gestita e applica hardening persistente del kernel di rete: rifiuta redirect e source-route, registra i martian, usa reverse-path filtering loose per WireGuard e disabilita il forwarding IPv4. SSH consente solo l’amministratore dichiarato tramite chiave pubblica; root, password, agent e forwarding
remoto sono disabilitati, mentre il forwarding locale resta disponibile per tunnel amministrativi privati. SMB3 pubblica `Archive` solo agli account Samba configurati con password in Vault e
ammette la LAN configurata su SMB3 cifrato e firmato, esclusivamente su TCP/445. NFSv4 esporta soltanto
`media/photobook` all'IP configurato di Aegis su TCP/2049, con `all_squash` verso UID/GID anonimi `1100`.

L'account di sistema `immich` usa UID/GID `1100`, shell senza login, nessuna appartenenza a `wheel` e
i gruppi supplementari `video` e `render`. I Quadlet rootful di Immich Server, ML, cache compatibile
Redis, PostgreSQL e NPM condividono una rete Podman. Immich viene eseguito come `1100:1100`; Server e
ML ricevono `/dev/dri` e Photobook e montato in sola lettura su `/external/photobook`. NPM pubblica `80` e
`443`, mentre l'amministrazione resta vincolata a `127.0.0.1:81` per l'accesso tramite tunnel SSH.

La fase 1 e limitata ai Quadlet utente rootless di Navidrome e Syncthing su Atlas. E abilitata nella
configurazione host di Atlas e puo essere impostata a `false` solo per una sospensione intenzionale. Navidrome ufficiale `0.63.2` usa il database SQLite sotto `/data` e
non supporta `ND_DATABASE_URL` ne un backend PostgreSQL esterno. Il servizio obsoleto `navidromedb`
e quindi rimosso da Prometheus invece di essere replicato su Atlas. Il ruolo deriva i percorsi dal
pool `zpool`, montato in `/zpool`: musica in sola lettura da `/zpool/media/music`, stato
applicativo Navidrome e `navidrome.db` in `/zpool/archive/app_data/navidrome` e dati Syncthing in
`/zpool/archive/app_data/syncthing`. `profile_atlas` crea questi dataset quando
`atlas_manage_storage` e attivo; il ruolo backend verifica i mountpoint esatti prima di avviare i
container. Il ruolo backend non crea mai il pool. Il ruolo separato `wireguard_overlay`
gestisce `wg0` tra Prometheus (`10.0.0.1`) e Atlas (`10.0.0.2`), genera una sola volta le chiavi
private sui rispettivi host e scambia tramite Ansible soltanto quelle pubbliche. Solo Prometheus apre
pubblicamente `51820/udp`. Le porte backend sono ammesse esclusivamente nella zona firewalld WireGuard.

`backend_phase1_start_services` resta falso durante il trasferimento dello stato applicativo, quindi
la prima esecuzione reale del backend genera i Quadlet senza creare un database Atlas vuoto. Dopo aver
arrestato Navidrome su Prometheus, copiare l'intera directory `/opt/navidrome/data/` in
`/zpool/archive/app_data/navidrome/`, preservando `navidrome.db` e gli eventuali file SQLite laterali.
Impostare quindi questa variabile a vero e rieseguire il ruolo per abilitare e avviare Navidrome e
Syncthing. Il playbook non copia e non elimina mai i dati applicativi.

Validare e generare i servizi Atlas con:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags storage

ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit prometheus,atlas --tags wireguard

ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags backend_phase1 --check --diff

ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags backend_phase1
```

Per il cutover, arrestare il vecchio Navidrome prima di copiare la sua directory dati, verificare
l'ownership dell'account `admin` su Atlas e confermare la presenza del database SQLite copiato prima
di impostare `backend_phase1_start_services: true` in `host_vars/atlas.yml`. Conservare i dati sorgente
e il container legacy `navidromedb` fermo finche Navidrome su Atlas e una prova di restore non sono
stati validati.

Restano da completare retention delle snapshot, topologia Syncthing, validazione WireGuard/firewall,
pull di backup da Prometheus, backup cifrati con Borg su una Hetzner Storage Box, backup USB,
monitoraggio e test di disaster recovery. Il backlog operativo dettagliato e in `AGENTS.md`.

---

# Composizione della configurazione

Emacs è abilitato sui profili Fedora/GNOME e workstation; la configurazione canonica è distribuita da `dotfiles_common`, con Org in `~/Org/`, template versionati e export PDF/HTML/Markdown/DOCX/ODT. Per abilitarlo temporaneamente su un altro profilo:

```bash
ansible-playbook ansible/site.yml --limit <host> --tags emacs -e emacs_enabled=true
```

La configurazione finale di una macchina è ottenuta combinando più livelli.

```text
common configuration
+ platform configuration
+ role configuration
+ desktop configuration
+ host overrides
```

Esempi correnti:

```text
ikaros -> common + platform_fedora + role_personal_workstation + graphical_desktop + desktop_gnome + ikaros
nymph  -> common + platform_fedora + graphical_desktop + desktop_gnome + nymph
deadalus -> common + platform_fedora + workstation_dev_fedora + workstation_dev_wsl + deadalus
```

Questo approccio consente di:

- mantenere configurazioni condivise
- applicare override specifici per host
- evitare duplicazioni
- riutilizzare il profilo Void corrente su un host futuro assegnandolo a
  `platform_void + graphical_desktop + desktop_sway`

---

# Ruoli Ansible

I principali ruoli attualmente presenti sono:

| Role                      | Descrizione                         |
| ------------------------- | ----------------------------------- |
| base                      | configurazione base comune          |
| packages_void             | installazione pacchetti su Void     |
| packages_fedora           | installazione pacchetti su Fedora   |
| packages_rocky            | installazione pacchetti su Rocky Linux 9 |
| services_runit            | gestione servizi runit              |
| services_systemd          | gestione servizi systemd            |
| profile_desktop_common    | bootstrap desktop Void condiviso    |
| profile_desktop_gnome     | dotfiles desktop condivisi per Fedora/GNOME |
| profile_desktop_sway      | sessione desktop sway / SwayFX (Wayland) |
| profile_desktop_niri     | sessione desktop Niri su Void (Wayland) |
| profile_desktop_host      | override desktop specifici per host |
| profile_personal_workstation | layer stabile per workstation personale |
| profile_workstation_dev_common | configurazione dev workstation condivisa |
| profile_workstation_dev_wsl | configurazione WSL condivisa per sviluppo |
| profile_server            | configurazione server               |
| profile_atlas             | configurazione NAS Rocky Linux 9    |
| profile_backend_phase1    | Navidrome e Syncthing rootless su Atlas |
| wireguard_overlay         | overlay WireGuard Prometheus/Atlas  |
| dotfiles_common           | distribuzione dotfiles comuni       |
| dotfiles                  | distribuzione configurazioni utente |

---

# Stato attuale del playbook principale

Il playbook `ansible/site.yml` e attualmente composto da blocchi per asse:

```text
all -> dotfiles_common
platform_void -> packages_void + services_runit
platform_void & graphical_desktop -> profile_desktop_common + profile_desktop_sway + profile_desktop_niri + profile_desktop_host
platform_fedora -> packages_fedora + services_systemd
platform_rocky -> packages_rocky + services_systemd
wireguard_overlay -> wireguard_overlay (dopo platform_rocky)
atlas -> profile_atlas
role_backend_phase1 -> profile_backend_phase1 (dopo atlas)
platform_fedora & role_personal_workstation -> profile_personal_workstation
platform_fedora & desktop_gnome -> profile_desktop_gnome
workstation_dev_fedora -> profile_workstation_dev_common
workstation_dev_wsl -> profile_workstation_dev_wsl (dopo platform_fedora + workstation_dev_fedora)
rocky_server -> dotfiles_common + profile_server (dopo platform_rocky)
```

Questo significa che, allo stato attuale:

- `ikaros` riceve Fedora Workstation/GNOME come target desktop personale stabile
- `nymph` riceve Fedora Workstation/GNOME come target laptop
- il profilo Void resta selezionabile tramite `platform_void + graphical_desktop` per host futuri
- `deadalus` riceve il profilo Fedora WSL tramite play dev dedicati
- il server Rocky (`prometheus`) e gestito con pacchetti, servizi, dotfiles server e firewalld
- il NAS Rocky (`atlas`) usa un pool ZFS gia esistente, condivisioni NFSv4/SMB limitate alla LAN e Cockpit/45Drives
- lo stack Compose server include soltanto `gitea` e `nginx-proxy-manager`; Navidrome e Syncthing
  della fase 1 sono Quadlet rootless su Atlas

# Dotfiles

La directory `dotfiles/` contiene le configurazioni utente versionate.

```text
dotfiles/
├── common
├── desktop
├── server
├── fedora
├── workstation
├── workstation_dev_wsl
└── nymph
```

Le configurazioni sono applicate tramite Ansible e organizzate per livelli:

| Livello | Scopo                            |
| ------- | -------------------------------- |
| common  | configurazioni condivise         |
| profile | configurazioni per tipo macchina |
| host    | override specifici               |

---

# Requisiti

Per utilizzare il repository sono necessari:

- Python 3
- Ansible
- `ansible-lint`
- `yamllint`
- `shellcheck`
- collection definite in `ansible/collections/requirements.yml`
- accesso locale o SSH alle macchine target, in base a come e definito l'inventory

Installazione base:

```bash
python3 -m pip install ansible ansible-lint yamllint shellcheck-py
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

Gestione segreti:

- il repository supporta il caricamento opzionale di `secrets/vault.yml`
- il repository supporta anche `secrets/vault.local.yml` per override locali non versionati
- `secrets/vault.yml.example` funge da template/esempio
- se `secrets/vault.yml` non e presente, il playbook continua comunque senza caricare variabili locali opzionali
- se `secrets/.vault_pass.gpg` esiste viene usato automaticamente per sbloccare i vault tramite `gpg`; in alternativa resta supportato `secrets/.vault_pass` come fallback legacy locale; se nessuno dei due file esiste Ansible richiede la password in modo interattivo

---

# Utilizzo

Eseguire il playbook principale:

```bash
ansible-playbook ansible/site.yml
```

Allo stato attuale questo comando:

- distribuisce i dotfiles comuni a tutti gli host
- per `platform_void` applica pacchetti Void e servizi runit
- per `platform_void + graphical_desktop` applica bootstrap desktop condiviso, sessioni Sway/Niri e override specifici per host
- per `platform_fedora` applica pacchetti Fedora e servizi systemd a `ikaros`, `nymph` e `deadalus`
- per `platform_fedora & role_personal_workstation` applica il layer personale a `ikaros`
- per `platform_fedora & desktop_gnome` applica il profilo GNOME a `ikaros` e `nymph`
- per `workstation_dev_wsl` applica i tweak WSL dopo il layer Fedora a `deadalus`, escludendo Flatpak e Snap
- per `platform_rocky` applica pacchetti Rocky e servizi systemd ad `atlas` e `prometheus`; quindi applica il profilo NAS ad `atlas` e il profilo server a `prometheus`
- non riavvia automaticamente il display manager
- carica `secrets/vault.yml` solo se presente
- carica `secrets/vault.local.yml` solo se presente, dopo `vault.yml`, cosi gli override locali hanno precedenza

Per validare prima di applicare:

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros,nymph --check --diff
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff
ansible-playbook ansible/site.yml --limit atlas --check --diff
ansible-lint ansible/site.yml
ansible-lint ansible/roles
yamllint ansible/
```

Per testare un override dell'utente server senza modificare l'inventory:

```bash
ansible-playbook ansible/site.yml --limit prometheus --check --diff -e server_username=myuser
```

Per validazioni piu mirate:

```bash
ansible-playbook ansible/site.yml --limit <host> --tags <tag1>,<tag2> --check --diff
ansible-playbook ansible/site.yml --limit <host> --start-at-task "<task name>" --check --diff
ansible-lint ansible/roles/<role>
yamllint ansible/path/to/file.yml
podman-compose -f /opt/docker/server/docker-compose.yml config
ansible-playbook ansible/site.yml --limit atlas --tags storage,sharing,containers --check --diff
ansible-playbook ansible/site.yml --limit atlas --tags backend_phase1 --check --diff
```

## Tag supportati dal playbook

Per vedere l'elenco reale aggiornato dei tag disponibili:

```bash
ansible-playbook ansible/site.yml --list-tags
```

Allo stato attuale `ansible/site.yml` espone questi tag:

| Tag | Scopo | Ambito principale |
| --- | --- | --- |
| `always` | pre-task sempre eseguiti, inclusi caricamento vault e validazioni preliminari | common |
| `ai_agents` | installazione agenti AI condivisi | Fedora, WSL |
| `atlas` | account, storage, condivisioni e container Atlas | NAS Atlas |
| `backend_phase1` | Quadlet rootless Navidrome e Syncthing | NAS Atlas |
| `containers` | Quadlet rootful Atlas | NAS Atlas |
| `dotfiles` | distribuzione/configurazione dotfiles | tutti i profili |
| `dotfiles:common` | dotfiles comuni condivisi | common, workstation, server |
| `dotfiles:desktop` | dotfiles desktop | desktop Void, Fedora/GNOME |
| `dotfiles:host` | override host-specifici desktop | desktop Void |
| `dotfiles:server` | dotfiles dedicati al profilo server | server |
| `dotfiles:workstation` | dotfiles dedicati alle workstation | personal workstation, WSL |
| `emptty` | gestione display manager `emptty` | desktop Void |
| `display-manager` | gestione del display manager `emptty` | desktop Void |
| `emacs` | configurazione Emacs condivisa e dipendenze di authoring | desktop Fedora/GNOME e workstation |
| `fonts` | installazione font | Fedora |
| `fzf` | configurazione FZF | dotfiles comuni |
| `git` | configurazione Git e GPG desktop | Fedora/GNOME, desktop Void |
| `gnome` | configurazione host GNOME | Fedora/GNOME desktop |
| `immich` | account e Quadlet Immich | NAS Atlas |
| `sway` | sessione/configurazione sway / SwayFX (Wayland) | desktop Void |
| `niri` | sessione/configurazione Niri (Wayland) | desktop Void |
| `npm` | installazione pacchetti npm globali | Fedora/GNOME, desktop Void, WSL |
| `nvidia` | componenti NVIDIA desktop | desktop Void |
| `packages` | installazione e aggiornamento pacchetti | tutti i profili |
| `podman` | integrazione Podman Compose e Quadlet rootless | server |
| `portal` | configurazione xdg-desktop-portal | desktop Void |
| `services` | gestione servizi runit/systemd | tutti i profili |
| `sharing` | condivisioni NFSv4 e SMB3 | NAS Atlas |
| `storage` | dataset ZFS figli | NAS Atlas |
| `theme` | configurazione del tema GTK/Qt | desktop Void |
| `tmux` | configurazione e plugin tmux | desktop Fedora/Void, WSL |
| `vim` | configurazione Vim | dotfiles comuni |
| `wireguard` | overlay WireGuard Prometheus/Atlas | Prometheus, NAS Atlas |
| `wsl` | bootstrap e configurazione WSL | WSL |

Esempi pratici:

```bash
ansible-playbook ansible/site.yml --limit nymph --tags dotfiles:desktop,gnome --check --diff
ansible-playbook ansible/site.yml --limit ikaros --tags gnome --check --diff
ansible-playbook ansible/site.yml --limit prometheus --tags services,dotfiles:server --check --diff
```

---

# Bootstrap di una nuova macchina

Una nuova macchina può essere inizializzata con i seguenti passaggi:

```bash
git clone <repo>
cd <repo-dir>
ansible-galaxy collection install -r ansible/collections/requirements.yml
ansible-playbook ansible/site.yml
```

Dopo l'esecuzione del playbook la macchina verra configurata secondo il profilo definito e i ruoli attualmente orchestrati.

Per aggiungere un nuovo host Void che riusa il profilo desktop preservato:

1. aggiungere l'host a `platform_void`;
2. aggiungerlo a `graphical_desktop`;
3. usare Sway, oppure aggiungerlo a `desktop_niri` per selezionare Niri;
4. lasciare eventuali dettagli hardware in `host_vars/<host>.yml`.

I gruppi legacy `void` e `desktop` sono parent di compatibilita, quindi un host
in `platform_void` e `graphical_desktop` continua a ricevere anche le variabili
Void e desktop esistenti.

Per il flusso mail desktop esiste inoltre uno script dedicato:

```bash
scripts/bootstrap_mail.sh
```

Lo script si occupa del bootstrap dei secret nel keyring, del primo sync con `mbsync` e dell'inizializzazione di `mu` usando la configurazione mail generata dai template.

Se modifichi questo script, valida almeno con:

```bash
sh -n scripts/bootstrap_mail.sh
shellcheck scripts/bootstrap_mail.sh
```

---

# Filosofia del progetto

Il repository segue alcuni principi chiave:

- Infrastructure as Code
- configurazione dichiarativa
- idempotenza
- ambienti riproducibili
- separazione tra configurazione sistema e configurazione utente

Questo consente di ricreare qualsiasi macchina partendo esclusivamente dal repository.

---

# Roadmap

Possibili evoluzioni future:

- hardening sicurezza server
- configurazione backup
- testing automatico playbook
- integrazione CI
- supporto ad altre distribuzioni Linux

---

# Licenza

Questo progetto è distribuito sotto licenza **LGPL-3.0**.
