---
conversation_id: "6ab1837e-8044-83ed-a832-40ea3c795642"
title: "Valutare backup Borg"
created: 2026-09-21
updated: 2026-09-21
model: "auto"
messages: 11
---

# Valutare backup Borg

## ChatGPT — 2026-09-21 21:20

Quel punto serve a verificare che il backup Borg che hai già configurato su Hetzner funzioni bene **non solo tecnicamente**, ma anche con il volume reale di dati che hai appena caricato in `/zpool/archive`.

Io lo dividerei in **due esecuzioni Borg**.

### 1. Primo backup con il pool popolato

Ora che `/zpool/archive` contiene i tuoi dati reali, fai partire manualmente lo stesso job Borg che normalmente viene eseguito dal timer systemd.

Alla fine ci interessano soprattutto quattro valori:

- **durata** del backup;
- **Original size** → quantità di dati letti dal NAS;
- **Deduplicated size** → quanto è stato effettivamente aggiunto al repository Hetzner;
- **dimensione complessiva del repository** dopo il backup.

Borg, nelle statistiche di `borg create`, mostra tipicamente qualcosa del genere:

```text
                       Original size      Compressed size    Deduplicated size
This archive:              850.00 GB           720.00 GB           610.00 GB
All archives:              ...
```

Il dato particolarmente interessante è `Deduplicated size`: ci dice quanto traffico/storage reale è servito per aggiungere questo nuovo archivio.

### 2. Fare un secondo backup senza grosse modifiche

Subito dopo — oppure il giorno successivo — facciamo girare Borg di nuovo.

Qui vogliamo vedere l'effetto della deduplicazione. Se hai, per esempio, **800 GB di dati** ma quasi nulla è cambiato, Borg non dovrebbe rispedire 800 GB a Hetzner.

Potresti vedere qualcosa concettualmente simile a:

```text
Original size:       800 GB
Compressed size:     700 GB
Deduplicated size:   30 MB
```

Questo è un test molto importante perché verifica che il comportamento incrementale sia quello atteso.

### 3. Poi facciamo una modifica controllata

A quel punto farei anche un piccolo test realistico: aggiungiamo qualche GB, modifichiamo alcuni file e magari cancelliamo/spostiamo qualcosa in `/zpool/archive`.

Lanciamo nuovamente Borg e controlliamo che vengano trasferiti sostanzialmente **solo i nuovi chunk**.

Questo ci permette anche di capire quanto tempo richiederanno normalmente i backup giornalieri rispetto al primo caricamento massivo.

### 4. Controlliamo il repository Hetzner

Infine confronterei:

```text
dati presenti sul NAS
        ↓
dimensione logica archivi Borg
        ↓
dimensione effettiva repository
```

Non dobbiamo aspettarci che questi numeri coincidano: compressione e soprattutto deduplicazione fanno sì che Borg possa conservare molti snapshot logici senza moltiplicare proporzionalmente lo spazio fisico.

Quindi il punto della checklist, in pratica, significa:

**backup completo reale → secondo backup incrementale → piccola modifica → altro incrementale → confronto delle statistiche.**

Dopo questi test avremo anche una baseline concreta del tipo *«Atlas contiene X TB, il primo offsite richiede Y ore, gli incrementali normali richiedono circa Z minuti e il repository cresce di N GB»*. A quel punto considero il Borg offsite veramente validato sotto carico e passerei al **backup USB offline**, usando lo stesso dataset reale come banco di prova.

## Utente — 2026-09-21 21:22

come controllo le esecuzioni di borg?

## ChatGPT — 2026-09-21 21:22

Visto che nel tuo setup Borg viene eseguito tramite **timer systemd**, hai tre livelli utili da controllare: timer → servizio → log Borg.

Per prima cosa vedrei quando è partito e quando partirà di nuovo:

```bash
systemctl list-timers --all | grep -i borg
```

Poi controllerei lo stato del timer e del relativo service. Se non ricordi i nomi esatti:

```bash
systemctl list-unit-files | grep -i borg
```

Una volta trovato, ad esempio `borg-backup.timer` / `borg-backup.service`:

```bash
systemctl status borg-backup.timer
systemctl status borg-backup.service
```

La cosa più utile per vedere **le esecuzioni passate** è però il journal:

```bash
journalctl -u borg-backup.service
```

Per l'ultima esecuzione:

```bash
journalctl -u borg-backup.service -n 200
```

oppure, molto comodo:

```bash
journalctl -u borg-backup.service --since today
```

Se vuoi seguire un'esecuzione mentre gira:

```bash
journalctl -fu borg-backup.service
```

### Controllare gli archivi effettivamente presenti

Il journal ti dice *se il job è stato eseguito*. Borg stesso invece ti permette di verificare *cosa è stato creato*.

A seconda della versione/configurazione Borg, puoi usare:

```bash
borg list "$BORG_REPO"
```

oppure con Borg 2:

```bash
borg repo-list "$BORG_REPO"
```

Dovresti vedere gli archivi con nome/data, quindi qualcosa concettualmente come:

```text
atlas-2026-09-19 ...
atlas-2026-09-20 ...
atlas-2026-09-21 ...
```

Per il test che vogliamo fare adesso, mi interessano soprattutto **i log dell'ultima esecuzione dopo che hai popolato `/zpool/archive`**. Se mi incolli:

```bash
systemctl list-timers --all | grep -i borg
```

e

```bash
systemctl status <nome-del-service-borg>
```

possiamo ricostruire esattamente **quando è girato l'ultimo backup, quanto è durato e se è terminato correttamente**.

## Utente — 2026-09-21 21:25

vedo una esecuzione di 16h fa ma non ci sono log

## ChatGPT — 2026-09-21 21:25

Sì, può succedere. Se `systemctl` mostra che il service Borg è stato eseguito 16 ore fa ma `journalctl` non mostra output, la prima cosa da capire è se **il service non produce proprio output** oppure se lo manda altrove.

Controllerei così, in quest'ordine:

```bash
systemctl status <borg-service> -l
```

Poi:

```bash
journalctl -u <borg-service> --since "24 hours ago" --no-pager
```

Se anche questo è vuoto, guarda direttamente come è definita l'unit:

```bash
systemctl cat <borg-service>
```

Qui ci interessano soprattutto:

```ini
ExecStart=...
StandardOutput=...
StandardError=...
```

Se `ExecStart` lancia uno script, guarda anche quello: potrebbe fare redirect tipo:

```bash
borg ... > /qualche/file.log 2>&1
```

oppure Borg potrebbe essere lanciato senza `--stats`, `--progress` o `--verbose`. In quel caso **un backup riuscito può produrre pochissimo o nessun output**, quindi systemd sa che il processo è terminato con successo ma non ha quasi niente da registrare.

Un altro controllo molto utile è:

```bash
systemctl show <borg-service> \
  -p ExecMainStartTimestamp \
  -p ExecMainExitTimestamp \
  -p ExecMainStatus \
  -p Result
```

Se trovi, per esempio:

```text
ExecMainStartTimestamp=Mon ...
ExecMainExitTimestamp=Mon ...
ExecMainStatus=0
Result=success
```

sappiamo almeno con certezza che il job è partito, quanto è durato e che è terminato con exit code `0`.

**Nel nostro caso però vogliamo anche le statistiche Borg**, perché dobbiamo valutare il backup del `/zpool/archive` appena popolato. Quindi prima di modificare nulla nella configurazione, incollami l'output di:

```bash
systemctl cat <borg-service>
```

Possiamo vedere come avevamo configurato Borg e capire perché non sta lasciando statistiche nel journal.

## Utente — 2026-09-21 21:31

[admin\@atlas \~]$ sudo systemctl cat atlas-borg-backup.service

# /etc/systemd/system/atlas-borg-backup.service

[Unit]
Description=Back up Atlas ZFS datasets to the encrypted Borg repository
Documentation=man:borg-create(1) man:borg-prune(1) man:borg-compact(1)
Requires=zfs.target
Wants=network-online.target
After=zfs.target network-online.target
StartLimitIntervalSec=6h
StartLimitBurst=3
ConditionFileIsExecutable=/usr/local/sbin/atlas-borg-backup
ConditionPathExists=/etc/atlas-borg/passphrase
ConditionPathExists=/etc/atlas-borg/id\_ed25519
ConditionPathExists=/etc/atlas-borg/known\_hosts

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/atlas-borg-backup
User=root
Group=root
UMask=0077
SuccessExitStatus=1
Restart=on-failure
RestartSec=30m
TimeoutStartSec=infinity
RuntimeDirectory=atlas-borg
RuntimeDirectoryMode=0750
Nice=15
IOSchedulingClass=best-effort
IOSchedulingPriority=7
NoNewPrivileges=true
PrivateMounts=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/cache/atlas-borg /var/lib/atlas-borg /run/atlas-borg /run/lock
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF\_UNIX AF\_INET AF\_INET6
RestrictRealtime=true
LockPersonality=true

## ChatGPT — 2026-09-21 21:31

Perfetto, qui vediamo che **systemd non sta redirigendo esplicitamente stdout/stderr**: non ci sono `StandardOutput=` o `StandardError=`. Quindi, normalmente, quello che `/usr/local/sbin/atlas-borg-backup` scrive su stdout/stderr dovrebbe finire nel journal.

Il prossimo pezzo da controllare è quindi proprio lo script:

```bash
sudo sed -n '1,240p' /usr/local/sbin/atlas-borg-backup
```

oppure:

```bash
sudo cat /usr/local/sbin/atlas-borg-backup
```

In particolare cercherei tre cose: il comando `borg create`, eventuali opzioni `--stats` / `--verbose`, e redirect come `>/dev/null`, `2>/dev/null` o verso file.

C'è però anche una cosa interessante nella unit:

```ini
SuccessExitStatus=1
```

Questo significa che systemd considera **anche exit code 1 come successo**. Con Borg, tipicamente `0` significa successo, `1` successo con warning e `2` errore. Quindi quella configurazione ha senso.

Per vedere cosa sa systemd dell'esecuzione di 16 ore fa, prova anche:

```bash
sudo systemctl show atlas-borg-backup.service \
  -p ExecMainStartTimestamp \
  -p ExecMainExitTimestamp \
  -p ExecMainStatus \
  -p Result
```

e:

```bash
sudo journalctl -u atlas-borg-backup.service \
  --since "24 hours ago" \
  --no-pager
```

Se il secondo continua a non mostrare le statistiche Borg, **non modificherei ancora la unit**. Incollami lo script `/usr/local/sbin/atlas-borg-backup`: quasi certamente lì capiremo dove finiscono i log e, soprattutto, se il job sta già raccogliendo `--stats` che ci servono per il test sul pool appena popolato.

## Utente — 2026-09-21 21:33

Result=success
ExecMainStartTimestamp=Mon 2026-09-21 04:47:56 CEST
ExecMainExitTimestamp=
ExecMainStatus=0

## ChatGPT — 2026-09-21 21:33

Questo output chiarisce parecchio: **il backup molto probabilmente è ancora in esecuzione**.

Hai:

```text
Result=success
ExecMainStartTimestamp=Mon 2026-09-21 04:47:56 CEST
ExecMainExitTimestamp=
ExecMainStatus=0
```

La cosa importante è:

```text
ExecMainExitTimestamp=
```

Non c'è ancora un timestamp di fine. Inoltre il tuo service ha:

```ini
Type=oneshot
TimeoutStartSec=infinity
```

quindi può tranquillamente rimanere attivo per molte ore mentre Borg trasferisce il primo grosso volume di dati.

Controlla subito:

```bash
sudo systemctl status atlas-borg-backup.service
```

Mi aspetto qualcosa tipo:

```text
Active: activating (start)
...
CGroup:
   ├─... /usr/local/sbin/atlas-borg-backup
   ├─... borg create ...
   └─... ssh ...
```

Puoi anche verificare direttamente i processi:

```bash
ps aux | grep '[b]org'
```

e:

```bash
ps aux | grep '[s]sh'
```

### Il `Result=success` qui è fuorviante

Non lo interpreterei ancora come *«il backup delle 04:47 è riuscito»*. Finché `ExecMainExitTimestamp` è vuoto, dobbiamo verificare lo stato corrente del servizio. `ExecMainStatus=0` non è una conferma sufficiente di completamento del job corrente.

E questo spiegherebbe perfettamente anche perché dici di non vedere i log finali: **le statistiche di `borg create --stats` vengono stampate alla conclusione dell'operazione**.

Dato che hai appena caricato tutto `/zpool/archive`, un primo backup offsite molto lungo è assolutamente plausibile: Borg deve leggere i nuovi dati, chunkarli, comprimerli/cifrarli e inviare i chunk mancanti alla Storage Box.

Fai:

```bash
sudo systemctl status atlas-borg-backup.service
```

Se risulta ancora `activating`, **non lo interromperei**. A quel punto possiamo anche vedere come monitorare l'avanzamento senza interferire con il backup.

## Utente — 2026-09-21 21:35

Si è activating ma quindi se è partito e nel frattempo aumento i dati che succede?

## ChatGPT — 2026-09-21 21:35

Dipende da **come lo script Borg prende i dati**, ma se sta facendo direttamente `borg create` sui dataset ZFS live, il backup **non rappresenta un'istantanea perfettamente coerente delle 04:47**.

Borg attraversa il filesystem mentre il backup è in corso. Quindi, se nel frattempo aggiungi dati in `/zpool/archive`, possono verificarsi casi diversi:

- un file aggiunto **prima che Borg visiti quella directory** può entrare nel backup corrente;
- un file aggiunto dopo che Borg ha già attraversato quella parte del filesystem probabilmente entrerà solo nel prossimo backup;
- un file modificato mentre Borg lo sta leggendo può generare un warning tipo *file changed while we backed it up* e Borg può terminare con codice `1`;
- file cancellati/spostati durante la scansione possono analogamente non essere rappresentati come ti aspetteresti.

Quindi l'archivio Borg rimane utilizzabile, ma temporalmente può essere una fotografia un po' "sfocata": alcuni dati possono rappresentare le 04:48, altri le 12:00, altri le 20:00.

### Nel tuo caso c'è una soluzione molto migliore: ZFS

Dato che Atlas usa ZFS, idealmente Borg dovrebbe fare backup **da uno snapshot ZFS**, non direttamente dal dataset live.

Concettualmente:

```text
/zpool/archive live
       │
       ├── modifiche continuano normalmente
       │
       └── snapshot @borg-20260921
                    │
                    └── Borg legge questo
```

Alle 04:47 crei lo snapshot. Da quel momento puoi continuare tranquillamente a copiare file sul NAS. Borg può metterci anche 20 ore: ciò che vede rimane esattamente lo stato del filesystem alle 04:47.

Questo ha un altro bel vantaggio nel tuo scenario: **se aggiungi 100 GB mentre Borg sta lavorando, quei 100 GB entreranno semplicemente nel backup successivo**.

Prima però non cambierei nulla mentre questo job sta girando. Lascialo terminare.

Poi guarderei `/usr/local/sbin/atlas-borg-backup`: se attualmente Borg legge direttamente `/zpool/...`, valuterei seriamente di modificare il design affinché faccia backup degli snapshot ZFS. È proprio uno dei vantaggi principali dell'accoppiata **ZFS + Borg**: ZFS ti dà una vista consistente nel tempo, Borg deduplicazione, cifratura, retention e copia offsite.

E visto che nella tua checklist hai già **snapshot ZFS ricorsivi**, potremmo anche verificare se conviene riutilizzare quelli esistenti invece di creare un secondo sistema di snapshot apposta per Borg. memcite
