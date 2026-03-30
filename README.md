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

Il repository modella attualmente tre tipologie di profilo.

Nota sullo stato attuale del playbook principale:

- `ansible/site.yml` applica oggi in automatico il profilo desktop su host Void Linux
- `ansible/site.yml` applica anche il profilo `ubuntu_workstation` con setup apt, systemd, dotfiles workstation, firewall UFW e integrazione GNOME
- `ansible/site.yml` applica anche il profilo `ubuntu_server` con baseline apt, systemd, dotfiles server e firewall UFW

## Desktop

Sistema operativo:

- Void Linux

Sessioni desktop:

- `ikaros`: i3
- `nymph`: i3 + Hyprland con scelta sessione a login

Macchine:

- `ikaros`
- `nymph`

Queste macchine condividono la stessa configurazione base desktop e vengono mantenute allineate tramite Ansible.

Lo stato attuale del profilo desktop include, tra le altre cose:

- dotfiles comuni e desktop
- sessione i3 su tutti i desktop Void e sessione Hyprland opzionale su `nymph`
- `emptty` con scelta sessione a login su `nymph` e default host-specific sugli altri desktop
- pacchetti Void Linux e servizi runit
- Flatpak con remoto Flathub
- GNOME Keyring e bootstrap della posta via script dedicato

---

## Workstation

Sistema operativo:

- Ubuntu LTS

Desktop environment:

- GNOME

Macchina:

- `deadalus`

Questo profilo è pensato per sviluppo e lavoro.

Il profilo workstation Ubuntu e agganciato al playbook principale e include gia una base operativa per uso desktop e sviluppo.

Lo stato attuale del profilo workstation include:

- installazione pacchetti base Ubuntu via apt
- installazione e configurazione di Docker dal repository ufficiale
- gestione dei dotfiles workstation e rendering dei template dedicati
- installazione di Google Chrome e pacchetti Snap workstation
- gestione delle estensioni GNOME da website e dello stato desiderato delle estensioni abilitate
- attivazione del firewall UFW

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
| services_runit            | gestione servizi runit              |
| services_systemd          | gestione servizi systemd            |
| profile_desktop_common    | bootstrap desktop Void condiviso    |
| profile_desktop_i3        | sessione desktop i3                 |
| profile_desktop_hyprland  | sessione desktop Hyprland           |
| profile_desktop_host      | override desktop specifici per host |
| profile_workstation_gnome | configurazione workstation GNOME    |
| profile_server            | configurazione server               |
| dotfiles_common           | distribuzione dotfiles comuni       |
| dotfiles                  | distribuzione configurazioni utente |

---

# Stato attuale del playbook principale

Il playbook `ansible/site.yml` e attualmente composto da quattro blocchi:

```text
all  -> dotfiles_common
void -> packages_void + services_runit + profile_desktop_common + profile_desktop_i3 + profile_desktop_hyprland + profile_desktop_host
ubuntu_workstation -> packages_ubuntu + services_systemd + profile_workstation_gnome
ubuntu_server -> packages_ubuntu + services_systemd + profile_server
```

Questo significa che, allo stato attuale:

- i desktop Void (`ikaros`, `nymph`) restano il target operativo piu completo
- la workstation Ubuntu (`deadalus`) e gestita con pacchetti, servizi, dotfiles, estensioni GNOME e firewall
- il server Ubuntu (`prometheus`) e gestito con pacchetti, servizi, dotfiles server e firewall

# Dotfiles

La directory `dotfiles/` contiene le configurazioni utente versionate.

```text
dotfiles/
├── common
├── desktop
├── server
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
- collection `community.general`
- accesso locale o SSH alle macchine target, in base a come e definito l'inventory

Installazione base:

```bash
pip install ansible
ansible-galaxy collection install community.general
```

Gestione segreti:

- il repository supporta il caricamento opzionale di `secrets/vault.yml`
- `secrets/vault.yml.example` funge da template/esempio
- se `secrets/vault.yml` non e presente, il playbook continua comunque senza caricare variabili locali opzionali

---

# Utilizzo

Eseguire il playbook principale:

```bash
ansible-playbook ansible/site.yml
```

Allo stato attuale questo comando:

- distribuisce i dotfiles comuni a tutti gli host
- per gli host Void applica bootstrap desktop condiviso, sessioni i3/Hyprland e override specifici per host
- per gli host `ubuntu_workstation` applica pacchetti Ubuntu, servizi systemd, profilo workstation GNOME, UFW, dotfiles, Snap e template dedicati
- per gli host `ubuntu_server` applica pacchetti Ubuntu, servizi systemd, profilo server, UFW, dotfiles e template dedicati
- non riavvia automaticamente `emptty`; le modifiche al display manager vanno applicate manualmente da SSH o da una TTY separata
- carica `secrets/vault.yml` solo se presente

Per validare prima di applicare:

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/site.yml --limit ikaros --check --diff
ansible-playbook ansible/site.yml --limit nymph --check --diff
ansible-playbook ansible/site.yml --limit deadalus --check --diff
ansible-playbook ansible/site.yml --limit prometheus --check --diff
```

---

# Bootstrap di una nuova macchina

Una nuova macchina può essere inizializzata con i seguenti passaggi:

```bash
git clone <repo>
cd infra
ansible-galaxy collection install community.general
ansible-playbook ansible/site.yml
```

Dopo l'esecuzione del playbook la macchina verra configurata secondo il profilo definito e i ruoli attualmente orchestrati.

Per il flusso mail desktop esiste inoltre uno script dedicato:

```bash
scripts/bootstrap_mail.sh
```

Lo script si occupa del bootstrap dei secret nel keyring, del primo sync con `mbsync` e dell'inizializzazione di `mu` usando la configurazione mail generata dai template.

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
