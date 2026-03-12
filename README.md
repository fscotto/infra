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
│   └── roles/
│
├── dotfiles/
│   ├── common/
│   ├── desktop/
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

Il sistema attualmente gestisce tre tipologie di profilo.

## Desktop

Sistema operativo:

- Void Linux

Window manager:

- i3

Macchine:

- `ikaros`
- `nymph`

Queste macchine condividono la stessa configurazione base desktop e vengono mantenute allineate tramite Ansible.

---

## Workstation

Sistema operativo:

- Ubuntu LTS

Desktop environment:

- GNOME

Macchina:

- `deadalus`

Questo profilo è pensato per sviluppo e lavoro.

---

## Server

Sistema operativo:

- Ubuntu LTS

Configurazione:

- nessun ambiente grafico

Macchina:

- `prometheus`

Profilo minimale orientato a servizi server.

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
| profile_desktop_i3        | configurazione desktop i3           |
| profile_workstation_gnome | configurazione workstation GNOME    |
| profile_server            | configurazione server               |
| dotfiles                  | distribuzione configurazioni utente |

---

# Dotfiles

La directory `dotfiles/` contiene le configurazioni utente versionate.

```text
dotfiles/
├── common
├── desktop
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
- accesso SSH alle macchine target

Installazione Ansible:

```bash
pip install ansible
```

---

# Utilizzo

Eseguire il playbook principale:

```bash
ansible-playbook ansible/site.yml
```

Questo comando:

- installa i pacchetti richiesti
- configura i servizi
- applica il profilo macchina
- distribuisce i dotfiles

---

# Bootstrap di una nuova macchina

Una nuova macchina può essere inizializzata con i seguenti passaggi:

```bash
git clone <repo>
cd infra
ansible-playbook ansible/site.yml
```

Dopo l'esecuzione del playbook la macchina verrà configurata secondo il profilo definito.

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

- gestione segreti con `ansible-vault`
- hardening sicurezza server
- configurazione backup
- testing automatico playbook
- integrazione CI
- supporto ad altre distribuzioni Linux

---

# Licenza

Questo progetto è distribuito sotto licenza **LGPL-3.0**.
