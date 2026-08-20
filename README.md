# Infra — Personal Infrastructure as Code

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
│   ├── ubuntu/
│   ├── server/
│   ├── workstation/
│   ├── workstation_host_linux/
│   ├── workstation_dev_wsl/
│   └── nymph/
│
├── scripts/
├── secrets/
└── README.md
```

Il repository è diviso in due componenti principali:

| Componente | Scopo                                  |
| ---------- | -------------------------------------- |
| ansible    | provisioning e configurazione macchine |
| dotfiles   | configurazioni utente versionate       |

---

# Macchine gestite

Il repository modella attualmente host Fedora/GNOME, un ambiente WSL di sviluppo e un server Ubuntu.
La composizione resta separata in assi indipendenti:

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
| deadalus-wsl | Ubuntu   | Workstation dev      | —       |
| prometheus   | Ubuntu   | Server               | —       |

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
- `ansible/site.yml` applica anche il ramo `workstation_dev_wsl` per il modello dev in WSL
- `ansible/site.yml` applica anche il profilo `ubuntu_server` con baseline apt, systemd, dotfiles server e firewall UFW

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

Sistemi operativi supportati:

- Ubuntu WSL, attualmente usato da `deadalus-wsl`
- Fedora Workstation nativa, disponibile per host futuri tramite gruppi dedicati

Desktop environment host Linux, per eventuali workstation native:

- GNOME

Macchine attuali:

- `deadalus-wsl` come ambiente dev Ubuntu in WSL sulla workstation Windows `deadalus`

Questo profilo è pensato per sviluppo e lavoro, con separazione tra layer host e layer dev.

Nel modello Ansible usato qui, un singolo inventory host puo appartenere intenzionalmente a piu gruppi e quindi ricevere piu play nello stesso run: l'associazione non e `1 host = 1 play`, ma `host + gruppi = layering finale`.

Il profilo workstation e agganciato al playbook principale e ora distingue:

- layer dev condiviso tra WSL e workstation Fedora future
- layer dev Fedora nativo disponibile per host futuri
- layer host Linux GNOME disponibile per host futuri
- layer WSL dedicato per sviluppo con `systemd`

Per esempio, lo stesso host Linux puo stare in `workstation_host_linux` e in `workstation_dev_fedora`, a seconda del layering che vuoi comporre.

Lo stato attuale del profilo workstation include:

- installazione pacchetti base Ubuntu via apt
- installazione pacchetti base Fedora via dnf per eventuali workstation native
- installazione e configurazione di Docker dal repository ufficiale
- gestione dei dotfiles workstation e rendering dei template dev condivisi
- installazione opzionale di Google Chrome, VS Code, IntelliJ IDEA Ultimate e applicazioni Flatpak per eventuali workstation Fedora native
- estensioni GNOME per eventuali host Linux nativi
- preparazione del ramo WSL Ubuntu con `systemd` per il toolchain di sviluppo
- attivazione del firewall `firewalld` sui target Fedora che dichiarano regole host-specifiche

Workflow WSL previsto:

1. avviare Ubuntu WSL almeno una volta e completare la creazione dell'utente Linux
2. installare Ansible dentro WSL Ubuntu
3. lanciare il playbook da WSL su `deadalus-wsl` per configurare l'ambiente dev locale
4. usare VS Code con le estensioni Remote (`WSL`, `SSH`, `Dev Containers`) dal lato Windows

---

## Server

Sistema operativo:

- Ubuntu LTS

Configurazione:

- nessun ambiente grafico

Macchina:

- `prometheus`

Profilo orientato a servizi server e gestione di dotfiles dedicati.

Lo stato attuale del profilo server include:

- installazione pacchetti base Ubuntu via apt
- installazione e configurazione di Docker dal repository ufficiale
- abilitazione dei servizi systemd dichiarati in inventory/group vars
- copia dei dotfiles server e rendering dei template server, incluso il `docker-compose.yml` dello stack servizi
- attivazione del firewall UFW con regola SSH esplicita
- apertura delle porte Syncthing `22000/tcp`, `22000/udp` e `21027/udp`, lasciando la GUI non esposta direttamente su UFW

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
| packages_freebsd          | installazione pacchetti su FreeBSD via pkg |
| packages_ubuntu           | installazione pacchetti su Ubuntu   |
| packages_fedora           | installazione pacchetti su Fedora   |
| services_runit            | gestione servizi runit              |
| services_systemd          | gestione servizi systemd            |
| services_freebsd          | gestione servizi FreeBSD dichiarati per host |
| profile_desktop_common    | bootstrap desktop Void condiviso    |
| profile_desktop_gnome     | dotfiles desktop condivisi per Fedora/GNOME |
| profile_desktop_sway      | sessione desktop sway / SwayFX (Wayland) |
| profile_desktop_niri     | sessione desktop Niri su Void (Wayland) |
| profile_desktop_host      | override desktop specifici per host |
| profile_personal_workstation | layer stabile per workstation personale |
| profile_workstation_dev_common | configurazione dev workstation condivisa |
| profile_workstation_gnome | configurazione host workstation GNOME |
| profile_workstation_dev_wsl | configurazione WSL Ubuntu per sviluppo |
| profile_server            | configurazione server               |
| dotfiles_common           | distribuzione dotfiles comuni       |
| dotfiles                  | distribuzione configurazioni utente |

---

# Stato attuale del playbook principale

Il playbook `ansible/site.yml` e attualmente composto da blocchi per asse:

```text
all -> dotfiles_common
platform_void -> packages_void + services_runit
platform_void & graphical_desktop -> profile_desktop_common + profile_desktop_sway + profile_desktop_niri + profile_desktop_host
platform_freebsd -> packages_freebsd + services_freebsd
platform_fedora -> packages_fedora + services_systemd
platform_fedora & role_personal_workstation -> profile_personal_workstation
platform_fedora & desktop_gnome -> profile_desktop_gnome
workstation_dev_fedora -> profile_workstation_dev_common
workstation_host_linux -> profile_workstation_gnome
workstation_dev_wsl -> packages_ubuntu + services_systemd + profile_workstation_dev_common + profile_workstation_dev_wsl
ubuntu_server -> packages_ubuntu + services_systemd + profile_server
```

Questo significa che, allo stato attuale:

- `ikaros` riceve Fedora Workstation/GNOME come target desktop personale stabile
- `nymph` riceve Fedora Workstation/GNOME come target laptop
- il profilo Void resta selezionabile tramite `platform_void + graphical_desktop` per host futuri
- il ramo WSL (`deadalus-wsl`) e predisposto con play dev dedicato
- il server Ubuntu (`prometheus`) e gestito con pacchetti, servizi, dotfiles server e firewall
- lo stack container server include `navidrome`, `postgres`, `gitea`, `nginx-proxy-manager` e `syncthing`, con GUI Syncthing raggiungibile tramite la rete Docker `web`

# Dotfiles

La directory `dotfiles/` contiene le configurazioni utente versionate.

```text
dotfiles/
├── common
├── desktop
├── server
├── fedora
├── ubuntu
├── workstation
├── workstation_host_linux
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
- per `platform_freebsd`, `workstation_dev_fedora` e `workstation_host_linux` non applica nulla finche quei gruppi restano senza host
- per `platform_fedora` applica pacchetti Fedora e servizi systemd a `ikaros` e `nymph`
- per `platform_fedora & role_personal_workstation` applica il layer personale a `ikaros`
- per `platform_fedora & desktop_gnome` applica il profilo GNOME a `ikaros` e `nymph`
- per `workstation_dev_wsl` applica pacchetti Ubuntu, servizi systemd, profilo dev comune e tweak WSL dedicati a `deadalus-wsl`
- per gli host `ubuntu_server` applica pacchetti Ubuntu, servizi systemd, profilo server, UFW, dotfiles e template dedicati
- non riavvia automaticamente il display manager
- carica `secrets/vault.yml` solo se presente
- carica `secrets/vault.local.yml` solo se presente, dopo `vault.yml`, cosi gli override locali hanno precedenza

Per validare prima di applicare:

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros,nymph --check --diff
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus-wsl --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff
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
docker compose -f /opt/docker/server/docker-compose.yml config
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
| `dotfiles` | distribuzione/configurazione dotfiles | tutti i profili |
| `dotfiles:common` | dotfiles comuni condivisi | common, workstation, server |
| `dotfiles:desktop` | dotfiles desktop | desktop Void, Fedora/GNOME |
| `dotfiles:host` | override host-specifici desktop | desktop Void |
| `dotfiles:server` | dotfiles dedicati al profilo server | server |
| `dotfiles:workstation` | dotfiles dedicati alle workstation | personal workstation, WSL, workstation Linux future |
| `emptty` | gestione display manager `emptty` | desktop Void |
| `display-manager` | gestione del display manager `emptty` | desktop Void |
| `emacs` | configurazione Emacs condivisa e dipendenze di authoring | desktop Fedora/GNOME e workstation |
| `fonts` | installazione font | Fedora |
| `fzf` | configurazione FZF | dotfiles comuni |
| `git` | configurazione Git e GPG desktop | Fedora/GNOME, desktop Void |
| `gnome` | configurazione host GNOME | Fedora/GNOME desktop, workstation host Linux future |
| `sway` | sessione/configurazione sway / SwayFX (Wayland) | desktop Void |
| `niri` | sessione/configurazione Niri (Wayland) | desktop Void |
| `npm` | installazione pacchetti npm globali | Fedora/GNOME, desktop Void, workstation Linux, WSL |
| `nvidia` | componenti NVIDIA desktop | desktop Void |
| `packages` | installazione e aggiornamento pacchetti | tutti i profili |
| `portal` | configurazione xdg-desktop-portal | desktop Void |
| `services` | gestione servizi runit/systemd | tutti i profili |
| `theme` | configurazione del tema GTK/Qt | desktop Void |
| `tmux` | configurazione e plugin tmux | desktop Fedora/Void, WSL |
| `vim` | configurazione Vim | dotfiles comuni |
| `vscode` | installazione/configurazione VS Code | workstation Fedora future, host Linux |
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

Per prove in VM sono disponibili gruppi di esempio in
`ansible/inventory/examples/platform-test-hosts.yml`, da passare esplicitamente
con `-i` insieme all'inventory principale.

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
