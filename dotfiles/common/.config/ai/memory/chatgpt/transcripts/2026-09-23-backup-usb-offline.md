---
conversation_id: "6ab3fa9e-ed44-83eb-a8dc-156cf0aa4f67"
title: "Backup USB offline"
created: 2026-09-23
updated: 2026-09-23
model: "auto"
messages: 1
---

# Backup USB offline

## ChatGPT — 2026-09-23 18:13

Quella voce indica un **terzo livello di backup**, fisicamente separato da Atlas e normalmente scollegato. L'idea è diversa sia dagli snapshot ZFS sia da Borg/Hetzner.

Immagina la situazione così:

```text
                    ┌─ ZFS snapshots
                    │  (stesso pool)
                    │
Atlas /zpool ───────┼─ Borg ──────────> Hetzner
                    │                    (off-site)
                    │
                    └─ rsync ─────────> HDD USB
                                         │
                                         └─ scollegato dopo il backup
```

Il disco USB servirebbe soprattutto come **backup offline**: ransomware, errore amministrativo grave, compromissione di Atlas/credenziali Borg o problemi lato provider non possono modificare un disco che sta fisicamente in un cassetto.

### Cosa significa "vincolato all'UUID"

Non vorrei uno script del tipo:

```bash
rsync ... /mnt/backup
```

perché se monti per errore un altro disco in `/mnt/backup`, potresti scrivere nel posto sbagliato.

Lo script dovrebbe invece verificare l'identità del filesystem, per esempio:

```text
collego HDD
    ↓
leggo UUID
    ↓
UUID == quello configurato?
    ├── NO → abort
    └── SI
         ↓
       mount
         ↓
       backup
         ↓
       verifica
         ↓
       umount
```

Quindi il playbook conoscerebbe qualcosa come `atlas_usb_backup_uuid`. Il disco può essere montato **solo per la durata del backup**.

### "rsync versionato" è la parte interessante

Non farei semplicemente una copia speculare:

```text
USB/
└── current/
```

Perché con un mirror puro, se cancelli accidentalmente `foto/2024` su Atlas e poi esegui rsync con `--delete`, hai propagato la cancellazione anche al backup.

Meglio qualcosa del genere:

```text
backup/
├── 2026-09-01/
├── 2026-09-15/
├── 2026-09-23/
└── latest -> 2026-09-23/
```

Ma senza duplicare fisicamente tutto ogni volta. Con `rsync --link-dest` i file che non sono cambiati diventano **hard link** alla versione precedente.

Se hai:

```text
backup 1:  2 TB
```

e al backup successivo cambiano solo 5 GB, non ottieni necessariamente altri 2 TB: gran parte dei file rimane condivisa tramite hard link e il nuovo snapshot consuma grossomodo lo spazio dei dati nuovi/modificati più metadata.

È una specie di **snapshotting povero ma molto semplice e trasparente**: puoi collegare il disco USB a un'altra macchina Linux e i backup sono normali directory e file. Nessun software particolare necessario per recuperarli.

### Perché rsync se hai già Borg?

Proprio perché offre **diversità tecnologica**.

Borg è ottimo per il backup remoto: cifratura, deduplicazione, compressione, retention. Ma per recuperarlo hai bisogno di repository Borg, Borg stesso, passphrase/chiave e repository integro.

Il disco USB con rsync invece sarebbe deliberatamente noioso:

```text
ext4/XFS
└── directory
    └── file normali
```

Se Atlas muore completamente, colleghi il disco a un'altra Linux box e copi i file.

Per il tuo setup mi piace parecchio avere:

| Livello | Protegge principalmente da |
|---|---|
| ZFS snapshot | cancellazioni/modifiche accidentali, rollback rapido |
| Borg → Hetzner | perdita di Atlas/dischi/casa, backup off-site |
| USB offline | compromissione, ransomware, problemi remoti, recovery semplice |

E soprattutto **USB non deve rimanere collegato**. Se rimane sempre attaccato ad Atlas perde buona parte del motivo per cui esiste.

### "verifiche e restore testato"

Questo secondo me è persino più importante dello script.

Dopo rsync non mi accontenterei di:

```text
rsync exit code = 0
```

Lo script dovrebbe almeno controllare che il filesystem corretto sia montato, che rsync termini correttamente e che il backup risultante abbia una struttura plausibile. Periodicamente farei poi un test vero:

```text
USB backup
   ↓
restore in /tmp/restore-test
   ↓
confronto con origine
   ↓
OK
```

Non necessariamente dell'intero multi-terabyte: puoi scegliere un campione significativo di directory/file e occasionalmente fare una verifica più completa.

Alla fine la routine potrebbe diventare molto semplice: **una volta ogni 2–4 settimane colleghi il disco USB, lanci un comando/systemd service, guardi che finisca correttamente, fai umount e rimetti il disco via**. Non automatizzerei troppo questa parte: il fatto che richieda intenzionalmente la presenza fisica del disco è una feature, non un difetto.

Nel tuo caso, dopo aver verificato il primo incrementale Borg, questa sarebbe proprio la parte che implementerei dopo: completa molto bene ZFS + Borg invece di duplicarne semplicemente le funzioni. memcite
