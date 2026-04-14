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
│   ├── server/
│   ├── workstation/
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

Il repository modella attualmente tre tipologie di profilo e prepara due filoni workstation: Linux nativa e Windows + WSL.

Nota sullo stato attuale del playbook principale:

- `ansible/site.yml` applica oggi in automatico il profilo desktop su host Void Linux
- `ansible/site.yml` applica la workstation Linux nativa separando il layer dev comune dal layer host GNOME
- `ansible/site.yml` applica anche il ramo `workstation_host_windows` + `workstation_dev_wsl` per il modello Windows 11 + WSL
- `ansible/site.yml` applica anche il profilo `ubuntu_server` con baseline apt, systemd, dotfiles server e firewall UFW

## Desktop

Sistema operativo:

- Void Linux

Sessioni desktop:

- `ikaros`: i3
- `nymph`: i3 + Sway + Hyprland con scelta sessione a login

Macchine:

- `ikaros`
- `nymph`

Queste macchine condividono la stessa configurazione base desktop e vengono mantenute allineate tramite Ansible.

Lo stato attuale del profilo desktop include, tra le altre cose:

- dotfiles comuni e desktop
- sessione i3 su tutti i desktop Void e sessioni Sway/Hyprland opzionali su `nymph`
- `emptty` con scelta sessione a login su `nymph` e default host-specific sugli altri desktop
- pacchetti Void Linux e servizi runit
- `turnstile` per i servizi utente, inclusi `emacs`, `ssh-agent` e `ollama`
- `ssh-agent` con socket stabile condiviso tra shell, SSH ed Emacs in `~/.local/state/ssh-agent/socket`
- `ollama` installato da tarball upstream e gestito come servizio utente `turnstile`, con `Codex CLI` installato globalmente via npm
- Flatpak con remoto Flathub
- GNOME Keyring e bootstrap della posta via script dedicato
- `Waybar` separata per compositor (`config-sway.jsonc` e `config-hyprland.jsonc`) con `style.css` condiviso
- `kanshi` su `nymph` per il profilo monitor Wayland, con workspace Sway deterministici: in dual monitor `1` resta su `eDP-1` e `2-10` vanno su `DP-1`, mentre in laptop-only tutti tornano su `eDP-1`

---

## Workstation

Sistemi operativi supportati:

- Ubuntu LTS nativa
- Fedora Workstation nativa
- Windows 11 host + Ubuntu WSL

Desktop environment host Linux:

- GNOME

Macchine attuali:

- `deadalus-ubuntu` come workstation Ubuntu nativa
- `deadalus-fedora` come workstation Fedora nativa
- supporto attivo per host Windows 11 + WSL tramite `deadalus-win` e `deadalus-wsl`

Questo profilo è pensato per sviluppo e lavoro, con separazione tra layer host e layer dev.

Nel modello Ansible usato qui, un singolo inventory host puo appartenere intenzionalmente a piu gruppi e quindi ricevere piu play nello stesso run: l'associazione non e `1 host = 1 play`, ma `host + gruppi = layering finale`.

Il profilo workstation e agganciato al playbook principale e ora distingue:

- layer dev Ubuntu condiviso tra workstation Linux nativa e Ubuntu in WSL
- layer dev Fedora nativo parallelo a Ubuntu
- layer host Linux GNOME
- layer host Windows 11 con bootstrap WSL, remoting `PSRP` su `HTTPS/5986`, gestione app via `winget` con backend configurabile e VS Code lato Windows
- layer WSL dedicato per sviluppo con `systemd`

Per esempio, lo stesso host Linux puo stare in `workstation_host_linux` e in `workstation_dev_fedora` oppure `workstation_dev_ubuntu`, a seconda del layering che vuoi comporre.

Lo stato attuale del profilo workstation include:

- installazione pacchetti base Ubuntu via apt
- installazione pacchetti base Fedora via dnf per il ramo workstation nativo
- installazione e configurazione di Docker dal repository ufficiale
- gestione dei dotfiles workstation e rendering dei template dev condivisi
- installazione di Google Chrome su Ubuntu e Fedora, `VS Code` su Fedora via repository RPM Microsoft, `IntelliJ IDEA Ultimate` su Fedora via COPR RPM, e applicazioni workstation residue su Fedora via Flatpak
- installazione di applicazioni workstation su Ubuntu nativa via Snap, oltre alle estensioni GNOME sul solo host Linux nativo
- configurazione del ramo Windows 11 host con app installate dal playbook via `winget`, con backend predefinito `winget_psrp`, tema scuro, pin della taskbar gestiti via policy locale e profilo predefinito di Windows Terminal impostato su `Ubuntu`
- preparazione del ramo WSL Ubuntu con `systemd` per il toolchain di sviluppo
- attivazione del firewall UFW su Ubuntu nativa e `firewalld` su Fedora nativa
- gestione di `gsettings` GNOME host-specifici su `deadalus-fedora`, inclusi shell, Files/Nautilus, file chooser GTK e GNOME Text Editor, allineati allo stato reale della macchina

Workflow Windows + WSL previsto:

Prima di eseguire il bootstrap Windows, apri PowerShell come amministratore e verifica la policy di esecuzione:

```powershell
Get-ExecutionPolicy -List
```

Se necessario, abilita l'esecuzione degli script per l'utente corrente:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Se Windows ha bloccato il file di bootstrap, sbloccalo esplicitamente:

```powershell
Unblock-File .\scripts\bootstrap_windows_workstation.ps1
```

1. eseguire `scripts/bootstrap_windows_workstation.ps1` su Windows come amministratore
2. riavviare Windows se richiesto dalle feature WSL
3. avviare Ubuntu WSL almeno una volta e completare la creazione dell'utente Linux
4. installare Ansible dentro WSL Ubuntu
5. lanciare il playbook da WSL su `deadalus-wsl` per configurare l'ambiente dev locale
6. lanciare da WSL anche il playbook su `deadalus-win` via `psrp` per configurare l'host Windows; per default il backend pacchetti Windows e `winget_psrp`
7. usare VS Code con le estensioni Remote (`WSL`, `SSH`, `Dev Containers`) dal lato Windows

Per il remoting Windows il repository usa di default `PSRP` con `Negotiate` su `HTTPS/5986`. L'utente di default puo essere un `MicrosoftAccount\...`, con host, utente e password forniti via vault o extra vars. Il backend pacchetti Windows e configurabile con `windows_package_backend` oppure `vault_windows_package_backend`; il default e `winget_psrp`.

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
- copia dei dotfiles server e rendering dei template server
- attivazione del firewall UFW con regola SSH esplicita

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
| profile_desktop_i3        | sessione desktop i3                 |
| profile_desktop_sway      | sessione desktop Sway               |
| profile_desktop_hyprland  | sessione desktop Hyprland           |
| profile_desktop_host      | override desktop specifici per host |
| profile_workstation_dev_common | configurazione dev workstation condivisa |
| profile_workstation_gnome | configurazione host workstation GNOME |
| profile_workstation_dev_wsl | configurazione WSL Ubuntu per sviluppo |
| profile_workstation_host_windows | configurazione host Windows 11 workstation |
| profile_server            | configurazione server               |
| dotfiles_common           | distribuzione dotfiles comuni       |
| dotfiles                  | distribuzione configurazioni utente |

---

# Stato attuale del playbook principale

Il playbook `ansible/site.yml` e attualmente composto da sette blocchi:

```text
all:!workstation_host_windows -> dotfiles_common
void -> packages_void + services_runit + profile_desktop_common + profile_desktop_i3 + profile_desktop_sway + profile_desktop_hyprland + profile_desktop_host
workstation_dev_ubuntu -> packages_ubuntu + services_systemd + profile_workstation_dev_common
workstation_dev_fedora -> packages_fedora + services_systemd + profile_workstation_dev_common
workstation_host_linux -> profile_workstation_gnome
workstation_dev_wsl -> packages_ubuntu + services_systemd + profile_workstation_dev_common + profile_workstation_dev_wsl
workstation_host_windows -> profile_workstation_host_windows
ubuntu_server -> packages_ubuntu + services_systemd + profile_server
```

Questo significa che, allo stato attuale:

- i desktop Void (`ikaros`, `nymph`) restano il target operativo piu completo
- la workstation Ubuntu (`deadalus-ubuntu`) e gestita separando ambiente dev e layer host GNOME
- la workstation Fedora (`deadalus-fedora`) usa lo stesso principio di composizione a gruppi con il ramo Fedora dedicato e con `gsettings` host-specifici dichiarati in inventory
- il ramo Windows + WSL e predisposto con bootstrap PowerShell e play Windows/WSL dedicati
- il server Ubuntu (`prometheus`) e gestito con pacchetti, servizi, dotfiles server e firewall

# Dotfiles

La directory `dotfiles/` contiene le configurazioni utente versionate.

```text
dotfiles/
├── common
├── desktop
├── server
├── fedora
├── workstation
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
- per il ramo Windows puoi anche definire `vault_windows_package_backend`, con valori supportati `winget_psrp` e `winget_wsl_local`; il default e `winget_psrp`

---

# Utilizzo

Eseguire il playbook principale:

```bash
ansible-playbook ansible/site.yml
```

Allo stato attuale questo comando:

- distribuisce i dotfiles comuni a tutti gli host
- per gli host Void applica bootstrap desktop condiviso, sessioni i3/Sway/Hyprland e override specifici per host
- per `workstation_dev_ubuntu` applica pacchetti Ubuntu, servizi systemd e profilo dev comune
- per `workstation_dev_fedora` applica pacchetti Fedora, servizi systemd e profilo dev comune
- per `workstation_host_linux` applica il layer host Linux GNOME
- per `workstation_dev_wsl` applica pacchetti Ubuntu, servizi systemd, profilo dev comune e tweak WSL dedicati
- per `workstation_host_windows` applica il layer host Windows 11 via PSRP, con installazione pacchetti Windows eseguita di default tramite `winget_psrp`
- per gli host `ubuntu_server` applica pacchetti Ubuntu, servizi systemd, profilo server, UFW, dotfiles e template dedicati
- non riavvia automaticamente `emptty`; le modifiche al display manager vanno applicate manualmente da SSH o da una TTY separata
- carica `secrets/vault.yml` solo se presente
- carica `secrets/vault.local.yml` solo se presente, dopo `vault.yml`, cosi gli override locali hanno precedenza

Per validare prima di applicare:

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus-ubuntu --check --diff
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
```

## Tag supportati dal playbook

Per vedere l'elenco reale aggiornato dei tag disponibili:

```bash
ansible-playbook ansible/site.yml --list-tags
```

Allo stato attuale `ansible/site.yml` espone questi tag:

| Tag | Scopo | Ambito principale |
| --- | --- | --- |
| `always` | pre-task sempre eseguiti, inclusi caricamento vault e validazioni preliminari | common, Windows |
| `dotfiles` | distribuzione/configurazione dotfiles | tutti i profili |
| `dotfiles:common` | dotfiles comuni condivisi | common, workstation, server |
| `dotfiles:desktop` | dotfiles desktop | desktop Void |
| `dotfiles:host` | override host-specifici desktop | desktop Void |
| `dotfiles:server` | dotfiles dedicati al profilo server | server |
| `dotfiles:workstation` | dotfiles dedicati alle workstation | workstation Linux, WSL |
| `emptty` | gestione display manager `emptty` | desktop Void |
| `gnome` | configurazione host GNOME | workstation host Linux, parte desktop |
| `hyprland` | sessione/configurazione Hyprland | desktop Void |
| `i3` | sessione/configurazione i3 | desktop Void |
| `nvidia` | componenti NVIDIA desktop | desktop Void |
| `packages` | installazione e aggiornamento pacchetti | tutti i profili |
| `services` | gestione servizi runit/systemd/Windows | tutti i profili |
| `sway` | sessione/configurazione Sway | desktop Void |
| `vscode` | installazione/configurazione VS Code | Fedora, host Linux, Windows |
| `wsl` | bootstrap e configurazione WSL | WSL, Windows |

Esempi pratici:

```bash
ansible-playbook ansible/site.yml --limit nymph --tags dotfiles:desktop,sway --check --diff
ansible-playbook ansible/site.yml --limit deadalus-fedora --tags packages,vscode --check --diff
ansible-playbook ansible/site.yml --limit prometheus --tags services,dotfiles:server --check --diff
```

Se tocchi `Waybar`, valida anche i config JSONC con:

```bash
python3 -m json.tool dotfiles/desktop/.config/waybar/config-sway.jsonc >/dev/null
python3 -m json.tool dotfiles/desktop/.config/waybar/config-hyprland.jsonc >/dev/null
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
