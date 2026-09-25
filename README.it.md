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

## Nodo pianificato e posticipato: Cerberus

`cerberus` e un nodo di management **posticipato**, in attesa dell'allestimento
fisico dell'ufficio nella nuova casa. Non e ancora presente nell'inventory e non
esistono ruoli o playbook che lo prendano come target.

L'hardware previsto e un Lenovo ThinkCentre M700 Tiny (Intel Core i3-6100T,
8 GB di RAM e SSD da 256 GB) con Ethernet nativa a 1 Gbps. Condividera monitor
e periferiche di Ikaros tramite uno switch KVM a ingressi multipli, usando un
cavo passivo DisplayPort-HDMI per il collegamento video. Il sistema operativo
previsto e Fedora Sericea, la variante Fedora immutabile con compositor Wayland
Sway.

Cerberus sara un management plane isolato: Ansible verra eseguito in un ambiente
Toolbox dedicato per il provisioning del futuro cluster `uranus`, anziche da
Ikaros o da un host non gestito. Lo stack di osservabilita rootless Podman
eseguira Grafana, Prometheus e Loki. L'SSD locale sara l'hot storage, con
metriche e log conservati per 30 giorni; esportazioni programmate trasferiranno
i dati storici piu vecchi su un dataset Atlas montato via NFS come cold storage.
Il piano di implementazione, con prerequisiti espliciti, e in `AGENTS.md`.

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

`atlas` è un NAS Rocky Linux 9 raggiunto via SSH. Normalmente il pool esiste già e il profilo gestisce
solo i dataset figli. La creazione iniziale del RAIDZ2 richiede esplicitamente `atlas_create_pool=true`
e quattro percorsi `/dev/disk/by-id/...` verificati in `atlas_zpool_disks`. Il ruolo non partiziona,
forza, distrugge, ripristina né modifica il layout vdev di un pool esistente. I client Linux usano NFSv4,
quelli Windows/WSL SMB; l'accesso è limitato alla LAN configurata.

Per il primo avvio servono `vault_atlas_admin_password_hash`, `vault_atlas_samba_password` e
`vault_atlas_immich_db_password`; il primo è un hash compatibile con `/etc/shadow`, non una password
Cockpit in chiaro. Il bootstrap usa l'amministratore preesistente:

```bash
ansible-playbook ansible/site.yml --limit atlas \
  -e atlas_connection_username=<existing-admin>
```

Le esecuzioni successive usano `atlas_admin_username`. Storage, condivisioni e firewall LAN sono
abilitati; prima dell'applicazione verificare pool, mountpoint, subnet e zona firewalld. La creazione
del pool è protetta da un gate esplicito e avviene solo se è assente. Atlas non fa più parte della VPN
WireGuard: la vecchia interfaccia è stata ritirata manualmente dopo la verifica del collegamento tra
Prometheus e Aegis. Le chiavi SSH autorizzate sono in file separati sotto
`~/.ssh/authorized_keys.d/`. `atlas_manage_media_stack` resta disabilitato finché `/dev/dri`, percorsi
dei container e segreto del database Immich non sono validati.

Sotto `zpool` Atlas crea `archive` (SMB), `services/data` con i dataset applicativi
`services/data/navidrome` e `services/data/syncthing`, `media`, `media/music`, `media/photobook` e
`backup/hosts/prometheus`. Archivio e applicazioni usano `zstd`; media, Syncthing e backup host usano
`lz4`. `backup` ha una riserva di `500G` che copre i discendenti. SELinux targeted è persistente;
l'eventuale riavvio necessario viene segnalato, non eseguito. Atlas assegna l'interfaccia primaria
alla zona firewalld gestita, rifiuta redirect e source route, registra i martian, mantiene il reverse-path
filter loose e disabilita il forwarding IPv4. SSH consente soltanto l'amministratore dichiarato con
chiave pubblica: root, password, agent forwarding e remote forwarding sono disabilitati, mentre il
forwarding locale resta disponibile per i tunnel amministrativi. SMB3 espone `Archive` agli account
autorizzati da Vault sulla LAN, solo su TCP/445 con cifratura e firma obbligatorie. NFSv4 espone
soltanto `media/photobook` all'IP di Aegis su TCP/2049, con `all_squash` verso UID/GID `1100`.

L'account di sistema `immich` usa UID/GID `1100`, non ha shell di login né gruppo `wheel` e riceve i
gruppi `video` e `render`. Lo stack Immich futuro prevede Quadlet rootful per Server, ML, cache,
PostgreSQL e NPM su una rete Podman comune. Immich gira come `1100:1100`, Server e ML ricevono
`/dev/dri` e Photobook è montato in sola lettura su `/external/photobook`. NPM pubblica `80` e `443`;
l'interfaccia amministrativa resta su `127.0.0.1:81`, raggiungibile via tunnel SSH.

Atlas ospita temporaneamente Navidrome e Syncthing rootless fino alla sostituzione con Uranus. I
servizi sono inizializzati **ex novo**, senza migrare lo stato precedente, rispettivamente sotto
`/zpool/services/data/navidrome` e `/zpool/services/data/syncthing`; la musica in
`/zpool/media/music` viene popolata separatamente. Sono vincolati all'indirizzo LAN di Atlas
(`192.168.178.55`), mai a WireGuard. `wireguard_overlay` collega invece Prometheus (`10.0.0.1`)
e Aegis (`10.0.0.2`): le chiavi private restano sui rispettivi host e Ansible scambia solo le pubbliche.
Prometheus apre `51820/udp`; Aegis inoltra soltanto il traffico overlay→LAN dichiarato e applica
source NAT, evitando interfacce VPN su Atlas/Uranus e route statiche sul router. Navidrome (`4533/tcp`)
e la GUI Syncthing (`8384/tcp`) ammettono solo Aegis, mentre le porte native Syncthing sono limitate
alla LAN. Dopo la verifica dei servizi, configurare manualmente i Proxy Host NPM verso
`http://192.168.178.55:4533` e `http://192.168.178.55:8384`. Il peer Prometheus include la LAN
negli `AllowedIPs`; aggiungere la VIP Uranus quando esisterà. Dopo il reload di firewalld, Ansible
ricarica le reti Podman rootful di Prometheus per conservare DNS e connettività del proxy.

Validare il gateway con:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit prometheus,aegis --tags wireguard --check --diff
```

La prima esecuzione reale WireGuard deve includere entrambi i peer. Se Aegis ha appena installato il
layer `wireguard-tools`, riavviarlo manualmente e rieseguire senza `--check`: il ruolo attende un
handshake effettivo.

Gli snapshot ZFS ricorsivi coprono l'intero pool: 24 orari al minuto 05, 30 giornalieri alle 00:15,
8 settimanali la domenica alle 01:00 e 12 mensili il primo giorno alle 02:00. La retention elimina
solo gli snapshot con prefisso gestito `atlas-auto` e non esegue rollback. Lo scrub OpenZFS mensile è
previsto la prima domenica alle 03:00; il timer settimanale incompatibile è disabilitato. Il primo
snapshot orario ricorsivo è riuscito; la prima pulizia pianificata e il primo scrub schedulato
richiedono ancora una verifica a runtime.

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags snapshots,scrub --check --diff
```

Il backup Borg cifrato usa il sub-account Hetzner `u660064-sub1`, il repository relativo `./borg-data`
e Borg remoto 1.4 su SSH porta 23. La chiave ED25519 del server è fissata; una chiave client dedicata
appartiene all'account `borg`, bloccato e senza login, sudo o gruppi supplementari. La chiave privata
resta in `/etc/atlas-borg`; la passphrase proviene da `vault_atlas_borg_passphrase` ed è resa in un
file `0600`. Solo il wrapper root crea snapshot e mount; avvia il client come `borg` con il minimo
accesso temporaneo in lettura, senza concedergli gestione ZFS o sudo.

Il backup giornaliero parte alle 04:30 con un ritardo casuale fino a 30 minuti. Crea uno snapshot ZFS
ricorsivo temporaneo e ricostruisce tutti i dataset sotto `/zpool` in un albero di bind mount in sola
lettura, per inserirli in un unico archivio coerente. Il wrapper smonta ricorsivamente l'albero privato;
un helper `ExecStopPost` mirato rimuove eventuali mount dello snapshot nel namespace host e lo snapshot
temporaneo dopo l'uscita del processo. Borg conserva 30 archivi giornalieri, 8 settimanali e 12
mensili, poi compatta il repository. Il controllo completo di metadati e repository si svolge il 15
di ogni mese alle 06:00. Le operazioni usano un lock comune, journal e retry systemd limitati. Le
nuove esecuzioni riportano al massimo una riga di avanzamento al minuto: percentuale **stimata**,
dataset, file elaborati e byte originali/compressi/deduplicati. Il denominatore è la somma dei
`logicalreferenced` ZFS dello snapshot, non un totale Borg: può superare il 100% e non comprende
retention, compattazione o controlli. Le righe di progresso non riportano i nomi dei file; eventuali
warning possono farlo. Seguire il job con `sudo journalctl -fu atlas-borg-backup.service`; modifiche
all'helper non cambiano un'esecuzione già avviata.

Attivazione iniziale esplicita:

1. Inserire una passphrase unica in `secrets/vault.yml` con `ansible-vault edit`.
2. Generare e mostrare solo la chiave pubblica con
   `ansible-playbook ansible/site.yml --limit atlas --tags borg_key`.
3. Installarla nel sub-account Hetzner, poi applicare con
   `ansible-playbook ansible/site.yml --limit atlas --tags packages,borg`.
4. Copiare `secrets/recovery/atlas-borg-repokey.export` su un supporto davvero offline: la copia
   locale ignorata da Git non è di per sé un backup offline.

Il ruolo inizializza solo un repository `repokey` assente, non accetta password SSH né host key non
fissate e non avvia manualmente il primo backup. Validazione:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags packages,borg --check --diff
```

L'attivazione iniziale è riuscita: backup e controllo del repository, restore completo in una
directory temporanea confrontato con l'albero `Archive`, esportazione offline della chiave di recupero
e pulizia di snapshot/mount temporanei. Il 2026-09-25 un test separato da snapshot ZFS giornaliero ha
copiato un file di `/zpool/archive` in `/var/tmp`, verificando contenuto, proprietario, modalità,
mtime e ACL POSIX; copia e mount temporanei sono stati rimossi senza interrompere Borg. Non è un test
di ripristino dell'intero dataset.

Il backup USB offline è distribuito come **servizio solo manuale** (`atlas_manage_usb_backup: true`):
Ansible non formatta, sblocca, monta né avvia automaticamente il disco. Il disco esistente è stato
verificato in sola lettura il 2026-09-23: UUID LUKS `577b3c43-ea37-4611-81a9-39d555cdfbd4`,
UUID ext4 interno `758e2d2e-a427-4797-aad9-39c3a9f17c7e`, mapper `zpool-backup`. All'ispezione
era montato in `/mnt/zpool-backup`; il servizio richiede invece che il mapper **non sia montato** prima
dell'avvio. Se serve, `systemd-ask-password` chiede interattivamente la passphrase LUKS tramite
l'agente di `systemctl start` e la passa direttamente a `cryptsetup`, senza salvarla, esporla negli
argomenti o memorizzarla nella cache. Lo script monta il disco privatamente, crea uno snapshot ZFS
ricorsivo, copia tutti i dataset in `atlas/snapshots/<timestamp>/` con `rsync --link-dest`, verifica
con un dry-run basato sui checksum, aggiorna atomicamente `atlas/latest`, smonta e chiude LUKS. Un
errore non sostituisce `latest` né cancella versioni complete precedenti. Borg e USB possono operare
contemporaneamente su snapshot distinti, ma la lettura concorrente può ridurre il throughput.

La copia USB conserva le ACL ma non gli attributi estesi generici, compreso `security.selinux`: la
policy della destinazione deve ricreare le etichette dopo un restore. Per un percorso esplicito:

```bash
ansible-playbook ansible/site.yml --limit atlas --tags restorecon \
  -e '{"atlas_restorecon_paths":["/zpool/archive"]}'
```

Il task accetta solo percorsi sotto la radice del pool Atlas, esegue `restorecon -RFv` solo su quelli
indicati ed è altrimenti inattivo; non va lanciato sull'intero pool durante i run ordinari. Le vecchie
versioni USB non vengono eliminate automaticamente senza una retention deliberata. Il controllo di
capacità include il trasferimento stimato e una riserva libera di 10 GiB. Dopo un backup riuscito,
scollegare fisicamente il disco per renderlo davvero offline.

Validare la configurazione senza avviare il backup e, separatamente, un eventuale relabel pianificato:

```bash
ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
ansible-playbook ansible/site.yml --limit atlas --tags usb_backup,usb_reminder --check --diff
ansible-playbook ansible/site.yml --limit atlas --tags restorecon --check \
  -e '{"atlas_restorecon_paths":["/zpool/archive"]}'
```

Prima dell'avvio manuale smontare in sicurezza `/mnt/zpool-backup`, se ancora montato. Con il mapper
chiuso, `sudo systemctl start atlas-usb-backup.service` chiede la passphrase e avvia il backup; né la
password LUKS né un keyfile vanno in Ansible. Seguire con
`sudo journalctl -fu atlas-usb-backup.service`. **Non esiste un timer di backup USB.** Soltanto
`atlas-usb-reminder.timer` è schedulato il primo sabato del mese alle 10:00 `Europe/Rome`: invia un
promemoria al notifier 45Drives Houston, senza avviare il backup. Un test manuale ha prodotto una
notifica in 45Drives Alerts, **non un'email**; il log conferma l'invio della notifica, non la consegna
di posta. Il primo evento pianificato era il 2026-10-03 alle 10:00 CEST. Controllare timer e risultato
con `systemctl list-timers atlas-usb-reminder.timer` e in 45Drives Alerts.

Il primo tentativo USB del 2026-09-23 fallì su `security.selinux` e, dopo l'interruzione, lasciò
snapshot e mapper aperti. Applicato il filtro rsync, furono rimossi lo snapshot fallito, il mapper
smontato e lo stato failed; non rimase una copia valida di quel tentativo. Un run del 2026-09-24
pubblicò una versione verificata ma fallì nella distruzione dello snapshot a causa di mount
`.zfs/snapshot` aperti nel namespace host. Dopo la pulizia non forzata, è stato aggiunto un helper
`ExecStopPost` mirato e testato con uno snapshot usa-e-getta. Un run successivo del 2026-09-24 ha
verificato i checksum, pubblicato la versione ed è terminato con successo: mapper chiuso, nessuno
snapshot USB temporaneo e pool sano. Il 2026-09-25 un test di restore indipendente ha aperto il disco
in sola lettura, montato ext4 con `ro,noload`, copiato un file di 5.707.945 byte da `atlas/latest` in
una directory vuota sotto `/var/tmp` e confrontato contenuto, proprietario, modalità, dimensione,
mtime e ACL POSIX. Il test ha rimosso copia e mount temporanei, chiuso LUKS e lasciato il pool sano
mentre Borg continuava. È un test su file, non un esercizio completo di disaster recovery.

Il monitoraggio Atlas è eseguito ogni 30 minuti da `atlas-health-monitor.timer`. Sonde in sola
lettura controllano stato/errori del pool e dei vdev, scrub/resilver, SMART dei quattro dischi del
pool e dell'NVMe di sistema, temperature dei dischi e CPU, spazio di sistema/pool/snapshot, crescita
di `zpool/backup` e quota Hetzner tramite `df -m` via SSH con l'account `borg` e la chiave fissata.
La query remota non apre il repository Borg né il suo lock. Gli alert di crescita richiedono una
baseline di circa 24 ore. Sono controllati anche attivazione e freschezza dei timer; hook systemd
`OnFailure` segnalano errori di snapshot, scrub, Borg, USB, promemoria e monitoraggio. Il monitor non
riavvia Borg; avvisa solo se un run supera 14 giorni. Soglie e percorsi stabili dei dischi sono nelle
variabili host. Gli avvisi usano 45Drives Houston con deduplicazione; **la consegna email non è stata
verificata**. Il controllo live del 2026-09-25 non ha trovato problemi; la notifica di prova è stata
inviata e lo Storage Box risultava occupato al 22%. Dimensione dell'archivio Borg e deduplicazione
dettagliata richiedono ancora la fine del backup in corso.

```bash
ansible-playbook ansible/site.yml --limit atlas --tags monitoring --check --diff
sudo /usr/local/libexec/atlas-health-monitor --dry-run
sudo journalctl -u atlas-health-monitor.service -n 100 --no-pager
systemctl list-timers atlas-health-monitor.timer
```

`--dry-run` non invia alert e non modifica lo stato del monitor. Un controllo reale si avvia con
`sudo systemctl start atlas-health-monitor.service`, senza avviare servizi di backup. Per una prova
etichettata di 45Drives Alerts usare
`sudo /usr/local/libexec/atlas-health-monitor --test-notification`.

### Timer systemd di Atlas

Tutti i nove timer gestiti sono abilitati. Gli orari sono locali ad Atlas (`Europe/Rome`); Borg e
monitoraggio aggiungono il ritardo casuale indicato. Tutti hanno `Persistent=true`: un evento perso
viene recuperato quando il timer torna attivo.

| Timer | Pianificazione (`OnCalendar`) | Azione |
| --- | --- | --- |
| `atlas-zfs-snapshot-hourly.timer` | `*-*-* *:05:00` — ogni ora al minuto 05 | Snapshot ricorsivo orario e retention |
| `atlas-zfs-snapshot-daily.timer` | `*-*-* 00:15:00` — ogni giorno alle 00:15 | Snapshot ricorsivo giornaliero e retention |
| `atlas-zfs-snapshot-weekly.timer` | `Sun *-*-* 01:00:00` — domenica alle 01:00 | Snapshot ricorsivo settimanale e retention |
| `atlas-zfs-snapshot-monthly.timer` | `*-*-01 02:00:00` — primo giorno del mese alle 02:00 | Snapshot ricorsivo mensile e retention |
| `zfs-scrub-monthly@zpool.timer` | `Sun *-*-01..07 03:00:00` — prima domenica alle 03:00 | Scrub ZFS |
| `atlas-borg-backup.timer` | `*-*-* 04:30:00` — ogni giorno alle 04:30, più 0–30 min casuali | Backup cifrato offsite |
| `atlas-borg-check.timer` | `*-*-15 06:00:00` — giorno 15 alle 06:00, più 0–30 min casuali | Controllo repository Borg |
| `atlas-usb-reminder.timer` | `Sat *-*-01..07 10:00:00 Europe/Rome` — primo sabato alle 10:00 | Solo promemoria 45Drives Alerts |
| `atlas-health-monitor.timer` | `*:0/30` — ogni mezz'ora, più 0–5 min casuali | Controlli di salute in sola lettura |

`atlas-usb-backup.service` **non ha timer** e va avviato manualmente. Il timer del fornitore
`zfs-scrub-weekly@zpool.timer` è disabilitato a favore dello scrub mensile. Il futuro pull del backup
Prometheus non ha ancora un timer, perché non è implementato. Durante un backup Borg attivo,
`systemctl list-timers` può mostrare `-` per il prossimo evento senza che il timer sia disabilitato.
Per vedere la pianificazione corrente: `systemctl list-timers --all` su Atlas.

Nextcloud è previsto come servizio temporaneo su Atlas prima di Uranus, ma solo dopo la validazione
della protezione dei dati: richiede storage applicativo, database e cache separati, segreti Vault,
pubblicazione solo tramite NPM e Aegis, procedure di backup, aggiornamento e migrazione. Non
distribuirlo prima di completare la checklist di protezione dei dati.

La destinazione futura per l'importazione foto iCloud è Atlas, non Aegis. Dopo la validazione dei
backup, pianificare una migrazione esplicita di iCloudPD con foto sotto `/zpool/archive/Pictures` e
stato applicativo/MFA fuori da `Archive`; testare permessi, SELinux, backup e restore prima del
cutover. L'attuale iCloudPD su Aegis e l'export NFS Photobook restano configurati fino
all'approvazione e alla verifica di questa migrazione separata. Anche il servizio Atlas sarà
temporaneo in attesa di Uranus.

Il pull dei backup di Prometheus, la valutazione delle dimensioni degli archivi Borg e i test completi
di disaster recovery restano da fare. Il backlog prioritizzato è in `AGENTS.md`.

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
