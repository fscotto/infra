---
conversation_id: "6aacdebe-cc08-83eb-a8bc-02affda0f2ca"
title: "Spiegare passphrase Borg"
created: 2026-09-18
updated: 2026-09-18
model: "auto"
messages: 7
---

# Spiegare passphrase Borg

## ChatGPT — 2026-09-18 08:50

`vault_atlas_borg_passphrase` è, in pratica, **la password crittografica del repository Borg**, conservata nel tuo Ansible Vault invece che in chiaro nel repository Git.

Nel setup che hai fatto, Borg usa `repokey`: Borg genera una chiave crittografica casuale e la conserva **dentro il repository**, ma cifrata/protetta dalla passphrase. Quindi Hetzner conserva sia i dati cifrati sia la repokey cifrata, ma senza la passphrase non può decifrare i backup. citeturn0search0turn0search12

In altre parole, ci sono **due credenziali completamente diverse**:

- la **chiave SSH di `borg`** (`/etc/atlas-borg/id_ed25519`) serve ad autenticare Atlas verso Hetzner;
- `vault_atlas_borg_passphrase` serve a **sbloccare la chiave crittografica Borg** e quindi a cifrare/decifrare il contenuto del backup.

Il nome `vault_atlas_borg_passphrase` è semplicemente una variabile Ansible scelta nella tua implementazione. Nel Vault avresti qualcosa concettualmente del genere:

```yaml
vault_atlas_borg_passphrase: "una-passphrase-molto-lunga-e-casuale"
```

Questa viene poi fornita a Borg durante l'esecuzione automatica. Borg supporta esplicitamente l'automazione tramite `BORG_PASSPHRASE` oppure, ancora meglio in certi setup, tramite `BORG_PASSCOMMAND` o un file descriptor. La documentazione mette in guardia dal passare la password direttamente sulla command line, perché potrebbe diventare visibile nella process list. citeturn0search0turn0search9

### Cosa metterei nel tuo Vault

Dato che non devi ricordarla per usarla quotidianamente, io genererei **una stringa casuale lunga**, anziché inventare una password umana. Per esempio sul tuo PC:

```bash
openssl rand -base64 48
```

Otterrai qualcosa del tipo:

```text
V7...una-lunga-stringa-casuale...Q=
```

e quella diventa il valore di `vault_atlas_borg_passphrase`.

Poi:

```bash
ansible-vault edit secrets/vault.yml
```

e aggiungi:

```yaml
vault_atlas_borg_passphrase: "LA_STRINGA_GENERATA"
```

Il punto importante è che **questa passphrase è materiale di disaster recovery**. Se perdi Atlas e devi ricostruire tutto da zero, per recuperare un repository `repokey` ti servono il repository/la repokey e la relativa passphrase. Borg raccomanda esplicitamente di conservare separatamente una copia della chiave e della passphrase. citeturn0search12

Nel tuo caso Codex aveva già previsto anche l'**export della recovery key cifrata**. Quindi io terrei fuori da Atlas almeno:

**export della Borg key + passphrase Borg + istruzioni minime per il restore.**

Idealmente la passphrase non dovrebbe esistere *soltanto* nell'Ansible Vault: se perdi contemporaneamente Atlas e il repository/playbook o la password del Vault, rischi di avere un backup perfettamente integro ma inutilizzabile. Una copia nel tuo password manager è sensata.

Quindi la catena è sostanzialmente:

```text
Ansible Vault
     │
     └── vault_atlas_borg_passphrase
                  │
                  ▼
             Borg client
                  │
        sblocca la repokey
                  │
                  ▼
        cifra i dati localmente
                  │
             SSH key borg
                  │
                  ▼
             Hetzner
        [solo dati cifrati]
```

Ed è proprio la separazione che vuoi: **la chiave SSH compromessa da sola non permette di leggere il backup; l'accesso allo Storage Box da solo non permette di leggerlo; serve anche la passphrase Borg.** citeturn0search0turn0search12

C'è però un dettaglio della tua implementazione che controllerei prima dell'attivazione: **come Codex sta trasferendo `vault_atlas_borg_passphrase` dal Vault al processo Borg sul server**. È lì che si decide se la gestione del secret è davvero pulita (file `0600`, `BORG_PASSCOMMAND`, environment systemd, ecc.).

## Utente — 2026-09-18 08:59

Quindi se ho ben capito mi dovrei conservare nel password manager la passphrase genereta perché senza quella non riesco a decifrare i dati, anche la chiave ssh caricata su hetzener publica e privata? dove hai messo la priva di quella ?

## ChatGPT — 2026-09-18 08:59

Esatto. La cosa importante è distinguere **credenziali di accesso** e **materiale necessario al disaster recovery**.

La **passphrase Borg va assolutamente conservata nel password manager**. Se perdi quella, con `repokey` non riesci più a decifrare il repository. Io conserverei anche l'**export della Borg recovery key** previsto dal setup: passphrase + recovery key esportata ti danno una protezione migliore in caso di problemi al repository.

Per la chiave SSH verso Hetzner, invece, la situazione è diversa. Dal lavoro fatto da Codex risulta:

```text
/etc/atlas-borg/id_ed25519       # PRIVATA
/etc/atlas-borg/id_ed25519.pub   # PUBBLICA
```

con:

```text
/etc/atlas-borg/id_ed25519       borg:borg 0600
/etc/atlas-borg/id_ed25519.pub   borg:borg 0644
```

La **pubblica** è quella che devi caricare sul sub-account Hetzner:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMowNw4UvYZ6cvyiGj+wr5PxukJEBDj9SDi3np51UoOr atlas-borg@atlas
```

La **privata è attualmente solo su Atlas**, in `/etc/atlas-borg/id_ed25519`.

Ma qui farei una distinzione importante: **non è indispensabile fare il backup della chiave SSH privata**. Se Atlas muore, puoi generare una nuova coppia SSH e sostituire la public key autorizzata su Hetzner. La chiave SSH non serve a decifrare Borg.

Quindi, per il disaster recovery, io organizzerei così:

| Elemento | Password manager / backup offline | Importanza |
|---|---|---|
| **Borg passphrase** | ✅ Sì | 🔴 Essenziale |
| **Borg recovery key export** | ✅ Sì | 🔴 Essenziale/fortemente consigliata |
| SSH private key `id_ed25519` | Facoltativo | 🟡 Rigenerabile |
| SSH public key | Non necessario | 🟢 Rigenerabile |
| Password Ansible Vault | ✅ Sì | 🔴 Necessaria per ricreare automaticamente il setup |

C'è anche un vantaggio nel **non conservare la chiave SSH privata** nel password manager: in un disaster recovery ne generi una nuova e autorizzi quella nuova su Hetzner. È una credenziale operativa, non la chiave dei tuoi dati.

Il vero "kit di sopravvivenza" del backup è quindi:

```text
Password manager / luogo sicuro
│
├── Borg passphrase            ← FONDAMENTALE
├── Borg recovery key export   ← FONDAMENTALE
└── Ansible Vault password
          │
          │
          ▼
       nuovo Atlas
          │
          ├── nuova SSH key ──────► Hetzner
          │
          └── Borg + passphrase ──► decrypt backup
```

E c'è una cosa che vorrei verificare nel codice generato da Codex: **dove viene salvato concretamente l'export della Borg recovery key**. Quello è molto più importante da portare fuori da Atlas rispetto alla chiave SSH privata.

## Utente — 2026-09-18 09:01

Ok la passphrase la devo generare io e metterla nel vault ma la borg recovery key come la esporto?

## ChatGPT — 2026-09-18 09:01

Sì. Però **la recovery key la puoi esportare solo dopo che il repository Borg è stato inizializzato**, perché viene generata da Borg durante `borg init`.

Nel tuo caso stai usando Borg 1.4 con `repokey`. La chiave crittografica viene memorizzata nel repository Hetzner, protetta dalla tua passphrase. Borg raccomanda comunque di esportarne una copia indipendente. citeturn0search0turn0search12

Il comando di base è:

```bash
borg key export <repository> /percorso/atlas-borg-key.export
```

Nel tuo setup, però, **non lo lancerei manualmente adesso**. Codex aveva già implementato l'esportazione della recovery key nel playbook. Prima farei completare l'inizializzazione del repository e lascerei al playbook la creazione dell'export, così usiamo esattamente `BORG_REPO`, SSH wrapper, utente `borg` e passphrase configurati dall'automazione.

Una volta ottenuto il file, hai questa coppia:

```text
atlas-borg-key.export     ← Borg recovery key cifrata
         +
passphrase                ← quella che generi tu
         ↓
possibilità di recuperare il repository
```

Una cosa interessante: **l'export non contiene la passphrase**. Rimane cifrato e per utilizzarlo nuovamente serve la passphrase originale. È esattamente il comportamento documentato da Borg. citeturn0search12

Per ripristinarlo, in Borg 1.x il comando corrispondente è:

```bash
borg key import <repository> atlas-borg-key.export
```

### Cosa farei nel tuo caso

Adesso genererei la passphrase:

```bash
openssl rand -base64 48
```

La salverei **immediatamente nel password manager**, poi la metterei anche nel tuo:

```yaml
vault_atlas_borg_passphrase: "..."
```

A quel punto fai inizializzare il repository dal playbook. Dopo l'inizializzazione possiamo recuperare il file `.export` generato dall'automazione e conservarlo **fuori da Atlas**.

Personalmente terrei:

```text
Password manager
└── Borg Atlas
    ├── Passphrase: xxxxxxxxx
    └── Recovery key: allegato atlas-borg-key.export
```

Se il tuo password manager supporta allegati, è una soluzione molto comoda. Altrimenti puoi tenere l'export in un secondo luogo sicuro/offline.

Borg offre anche una soluzione molto carina per un'ulteriore copia di emergenza:

```bash
borg key export --paper <repository> atlas-borg-key.txt
```

che genera una rappresentazione pensata apposta per essere **stampata e conservata fisicamente**. citeturn0search12

Quindi non hai bisogno di salvare la SSH private key di Atlas per poter recuperare i dati. **Passphrase Borg + Borg key export sono le due cose che proteggerei davvero per il disaster recovery**; l'accesso SSH a Hetzner può essere ricreato con una nuova coppia di chiavi.

## Utente — 2026-09-18 09:04

come devo lanciare il playbook?

## ChatGPT — 2026-09-18 09:04

Dal contesto del repository, il playbook principale è `ansible/site.yml`, l'host è `atlas` e hai già i tag `borg` / `borg_key`.

Se hai appena aggiunto `vault_atlas_borg_passphrase` dentro `secrets/vault.yml`, per applicare **tutta la configurazione Borg** ad Atlas lancerei dalla root del repository:

```bash
ansible-playbook ansible/site.yml \
  --limit atlas \
  --tags borg \
  --ask-vault-pass
```

`--ask-vault-pass` ti chiederà la password con cui hai cifrato l'Ansible Vault. **Non è la passphrase Borg**: quella viene letta dal Vault come `vault_atlas_borg_passphrase`.

Quindi il flusso è:

```text
secrets/vault.yml
└── vault_atlas_borg_passphrase: "..."
             │
             ▼
ansible-playbook
             │
             ├── configura utente borg
             ├── configura SSH verso Hetzner
             ├── installa/configura Borg
             ├── inizializza repository
             ├── esporta Borg key
             └── configura service/timer systemd
```

**Prima di lanciarlo**, però, assicurati di aver già caricato su Hetzner questa public key dell'utente `borg`:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMowNw4UvYZ6cvyiGj+wr5PxukJEBDj9SDi3np51UoOr atlas-borg@atlas
```

Altrimenti il playbook arriverà al punto in cui deve contattare il repository Hetzner e l'autenticazione SSH fallirà.

Se vuoi essere prudente, puoi prima fare:

```bash
ansible-playbook ansible/site.yml \
  --limit atlas \
  --tags borg \
  --ask-vault-pass \
  --check --diff
```

e poi togliere `--check --diff` per l'esecuzione reale.

**Attenzione però a un dettaglio:** dal lavoro precedente di Codex sappiamo che `borg_key` è stato eseguito e testato separatamente, ma non ho davanti il contenuto attuale del playbook per confermare se `--tags borg` includa *anche* inizializzazione repository ed export della recovery key. Se vuoi evitare di andare a tentativi, posso controllare il repository attuale e dirti **il comando esatto da eseguire e cosa farà, task per task**.
