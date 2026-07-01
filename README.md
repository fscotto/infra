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
│   ├── ikaros/
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

Il repository modella attualmente tre tipologie di profilo, con i filoni workstation Linux nativa e WSL.

Nota sullo stato attuale del playbook principale:

- `ansible/site.yml` applica oggi in automatico il profilo desktop su host Void Linux
- `ansible/site.yml` applica la workstation Linux nativa separando il layer dev comune dal layer host GNOME
- `ansible/site.yml` applica anche il ramo `workstation_dev_wsl` per il modello dev in WSL
- `ansible/site.yml` applica anche il profilo `ubuntu_server` con baseline apt, systemd, dotfiles server e firewall UFW

## Desktop

Sistema operativo:

- Void Linux

Modalita desktop:

- `minimal`: sway (Wayland) + Hyprland (Wayland), gestite da `emptty`
- `xfce`: XFCE puro con look scuro e sobrio, gestito da LightDM
- `kde`: KDE Plasma, gestito da SDDM

Macchine:

- `ikaros`
- `nymph`

Queste macchine condividono la stessa configurazione base desktop e vengono mantenute allineate tramite Ansible. `desktop_environment` seleziona in modo esclusivo `minimal` (default), `xfce` oppure `kde`. Nella modalita minimale Sway/SwayFX e Hyprland sono installate in parallelo e selezionabili da `emptty`; `desktop_default_session` decide quale sessione viene preselezionata al login. XFCE usa direttamente la sessione `xfce` tramite LightDM.

Lo stato attuale del profilo desktop include, tra le altre cose:

- dotfiles comuni e desktop
- sessioni sway e Hyprland su entrambi gli host in modalita `minimal`
- KDE Plasma con applicazioni KDE curate e SDDM disponibile come alternativa esclusiva
- XFCE con pannello, keybinding, terminale, tema e workspace dichiarativi, LightDM e Thunderbird come client grafico principale
- `emptty` con default host-specific in modalita `minimal`, con session file Wayland esposti per `sway` e `hyprland`
- pacchetti Void Linux e servizi runit; le liste pacchetti Void desktop sono separate per criterio:
  - `void_packages_base` per il runtime sistema (init, kernel, audio core, networking, firewall, hw daemons)
  - `desktop_common_packages` per l'infrastruttura condivisa dalle modalita
  - `desktop_minimal_packages` per applicazioni GTK/XFCE e `emptty`
  - `desktop_xfce_packages` per XFCE, LightDM e le relative integrazioni
  - `desktop_kde_packages` per Plasma, SDDM e le applicazioni KDE equivalenti
  - `desktop_sway_packages` e `desktop_hyprland_packages` per i binari specifici di ciascuna sessione
- `turnstile` per i servizi utente, inclusi `emacs` e `ssh-agent`
- `ssh-agent` con socket stabile condiviso tra shell, SSH ed Emacs in `~/.local/state/ssh-agent/socket`
- `.emacs.d` distribuito da un task dedicato Ansible con tag `emacs`
- `tmux` con plugin gestiti da TPM al bootstrap del profilo desktop
- Flatpak con remoto Flathub
- GNOME Keyring e `udiskie` nella modalita minimale; KWallet e integrazione UDisks di Plasma nella modalita KDE
- multi-monitor: sotto sway è gestito da `kanshi` (config host-specifica in `host_sway_dotfiles` su `nymph`); sotto Hyprland gli override monitor vivono in `host_hyprland_dotfiles`
- override NVIDIA Optimus su `nymph`: parametri kernel GRUB iniettati in modo idempotente in `GRUB_CMDLINE_LINUX`, wrapper `prime-run` e config WirePlumber per priorità telecamera

---

## Workstation

Sistemi operativi supportati:

- Fedora Workstation nativa
- Ubuntu WSL

Desktop environment host Linux:

- GNOME

Macchine attuali:

- `deadalus-fedora` come workstation Fedora nativa
- `deadalus-wsl` come ambiente dev Ubuntu in WSL

Questo profilo è pensato per sviluppo e lavoro, con separazione tra layer host e layer dev.

Nel modello Ansible usato qui, un singolo inventory host puo appartenere intenzionalmente a piu gruppi e quindi ricevere piu play nello stesso run: l'associazione non e `1 host = 1 play`, ma `host + gruppi = layering finale`.

Il profilo workstation e agganciato al playbook principale e ora distingue:

- layer dev Ubuntu condiviso tra WSL e server
- layer dev Fedora nativo
- layer host Linux GNOME
- layer WSL dedicato per sviluppo con `systemd`

Per esempio, lo stesso host Linux puo stare in `workstation_host_linux` e in `workstation_dev_fedora`, a seconda del layering che vuoi comporre.

Lo stato attuale del profilo workstation include:

- installazione pacchetti base Ubuntu via apt
- installazione pacchetti base Fedora via dnf per il ramo workstation nativo
- installazione e configurazione di Docker dal repository ufficiale
- gestione dei dotfiles workstation e rendering dei template dev condivisi
- installazione di Google Chrome su Fedora, `VS Code` su Fedora via repository RPM Microsoft, `IntelliJ IDEA Ultimate` su Fedora via COPR RPM, e applicazioni workstation residue su Fedora via Flatpak
- estensioni GNOME sul solo host Linux nativo
- preparazione del ramo WSL Ubuntu con `systemd` per il toolchain di sviluppo
- attivazione del firewall `firewalld` su Fedora nativa
- gestione di `gsettings` GNOME host-specifici su `deadalus-fedora`, inclusi shell, Files/Nautilus, file chooser GTK e GNOME Text Editor, allineati allo stato reale della macchina

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

Deploy mirato della configurazione Emacs sui desktop Void:

```bash
ansible-playbook ansible/site.yml --limit ikaros --tags emacs
ansible-playbook ansible/site.yml --limit nymph --tags emacs
```

La configurazione finale di una macchina è ottenuta combinando più livelli.

```text
common configuration
+ OS configuration
+ profile configuration
+ host overrides
```

Esempio per `ikaros`:

```text
common + void + desktop + ikaros
```

Esempio per `nymph`:

```text
common + void + desktop + nymph
```

Questo approccio consente di:

- mantenere configurazioni condivise
- applicare override specifici per host
- evitare duplicazioni

---

# Ruoli Ansible

I principali ruoli attualmente presenti sono:

| Role                      | Descrizione                         |
| ------------------------- | ----------------------------------- |
| base                      | configurazione base comune          |
| packages_void             | installazione pacchetti su Void     |
| packages_ubuntu           | installazione pacchetti su Ubuntu   |
| packages_fedora           | installazione pacchetti su Fedora   |
| services_runit            | gestione servizi runit              |
| services_systemd          | gestione servizi systemd            |
| profile_desktop_common    | bootstrap desktop Void condiviso    |
| profile_desktop_sway      | sessione desktop sway / SwayFX (Wayland) |
| profile_desktop_hyprland  | sessione desktop Hyprland (Wayland) |
| profile_desktop_host      | override desktop specifici per host |
| profile_workstation_dev_common | configurazione dev workstation condivisa |
| profile_workstation_gnome | configurazione host workstation GNOME |
| profile_workstation_dev_wsl | configurazione WSL Ubuntu per sviluppo |
| profile_server            | configurazione server               |
| dotfiles_common           | distribuzione dotfiles comuni       |
| dotfiles                  | distribuzione configurazioni utente |

---

# Stato attuale del playbook principale

Il playbook `ansible/site.yml` e attualmente composto da sei blocchi:

```text
all -> dotfiles_common
void -> packages_void + services_runit + profile_desktop_common + profile_desktop_sway + profile_desktop_hyprland + profile_desktop_host
workstation_dev_fedora -> packages_fedora + services_systemd + profile_workstation_dev_common
workstation_host_linux -> profile_workstation_gnome
workstation_dev_wsl -> packages_ubuntu + services_systemd + profile_workstation_dev_common + profile_workstation_dev_wsl
ubuntu_server -> packages_ubuntu + services_systemd + profile_server
```

Questo significa che, allo stato attuale:

- i desktop Void (`ikaros`, `nymph`) restano il target operativo piu completo
- la workstation Fedora (`deadalus-fedora`) usa il principio di composizione a gruppi con il ramo Fedora dedicato e con `gsettings` host-specifici dichiarati in inventory
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
├── ikaros
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
- per gli host Void applica bootstrap desktop condiviso, sessioni sway/Hyprland e override specifici per host
- per `workstation_dev_fedora` applica pacchetti Fedora, servizi systemd e profilo dev comune
- per `workstation_host_linux` applica il layer host Linux GNOME
- per `workstation_dev_wsl` applica pacchetti Ubuntu, servizi systemd, profilo dev comune e tweak WSL dedicati
- per gli host `ubuntu_server` applica pacchetti Ubuntu, servizi systemd, profilo server, UFW, dotfiles e template dedicati
- non riavvia automaticamente il display manager; i passaggi tra `emptty`, LightDM e SDDM vanno applicati da SSH o da una TTY separata
- carica `secrets/vault.yml` solo se presente
- carica `secrets/vault.local.yml` solo se presente, dopo `vault.yml`, cosi gli override locali hanno precedenza

Per validare prima di applicare:

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus-fedora --check --diff
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

Per attivare XFCE o KDE su un host, impostare rispettivamente `desktop_environment: xfce` o `desktop_environment: kde` nei relativi `host_vars` ed eseguire prima un dry run. Il primo play configura il profilo ma, se un altro display manager e ancora attivo, rinvia il cambio. Da una TTY o sessione SSH separata, con la sessione grafica chiusa, applicare quindi il passaggio esplicito:

```bash
ansible-playbook ansible/site.yml --limit <host> -e desktop_allow_display_manager_switch=true
```

La stessa procedura vale per ogni passaggio tra `minimal`, `xfce` e `kde`. Gli XML XFCE sono autorevoli: applicare i relativi aggiornamenti mentre XFCE e disconnesso evita che `xfconfd` ripristini lo stato in memoria.

Allo stato attuale `ansible/site.yml` espone questi tag:

| Tag | Scopo | Ambito principale |
| --- | --- | --- |
| `always` | pre-task sempre eseguiti, inclusi caricamento vault e validazioni preliminari | common |
| `dotfiles` | distribuzione/configurazione dotfiles | tutti i profili |
| `dotfiles:common` | dotfiles comuni condivisi | common, workstation, server |
| `dotfiles:desktop` | dotfiles desktop | desktop Void |
| `dotfiles:host` | override host-specifici desktop | desktop Void |
| `dotfiles:server` | dotfiles dedicati al profilo server | server |
| `dotfiles:workstation` | dotfiles dedicati alle workstation | workstation Linux, WSL |
| `emptty` | gestione display manager `emptty` | desktop Void |
| `display-manager` | selezione protetta tra `emptty`, LightDM e SDDM | desktop Void |
| `kde` | profilo KDE Plasma e relativa pulizia | desktop Void |
| `xfce` | profilo XFCE, LightDM e relativa pulizia | desktop Void |
| `gnome` | configurazione host GNOME | workstation host Linux, parte desktop |
| `sway` | sessione/configurazione sway / SwayFX (Wayland) | desktop Void |
| `hyprland` | sessione/configurazione Hyprland (Wayland) | desktop Void |
| `npm` | installazione pacchetti npm globali | desktop Void, workstation Linux, WSL |
| `nvidia` | componenti NVIDIA desktop | desktop Void |
| `packages` | installazione e aggiornamento pacchetti | tutti i profili |
| `services` | gestione servizi runit/systemd | tutti i profili |
| `vscode` | installazione/configurazione VS Code | Fedora, host Linux |
| `wsl` | bootstrap e configurazione WSL | WSL |

Esempi pratici:

```bash
ansible-playbook ansible/site.yml --limit nymph --tags dotfiles:desktop,sway --check --diff
ansible-playbook ansible/site.yml --limit ikaros --tags sway,portal --check --diff
ansible-playbook ansible/site.yml --limit ikaros --tags hyprland,portal --check --diff
ansible-playbook ansible/site.yml --limit deadalus-fedora --tags packages,vscode --check --diff
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
