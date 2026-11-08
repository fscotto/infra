---
conversation_id: "6a6c961b-c828-83eb-8b57-2bf590ca385e"
title: "Progetto fsnap per APUE"
created: 2026-07-31
updated: 2026-08-15
model: "gpt-5-6-thinking"
messages: 26
---

# Progetto fsnap per APUE

## Utente — 2026-07-31 14:35

Adesso che ho definito il mio ambiente di lavoro voglio andare avanti con l'acquisizione delle competenza da sviluppatore di sistema.
Sono arrivato ad iniziare il capitolo 6 di APUE ma vorrei fermare bene i concetti presenti nei primi 5 capitoli sviluppando qualcosa, che cosa mi consigli?

## ChatGPT — 2026-07-31 14:35

Ti consiglierei un progetto unico, abbastanza “vero” da costringerti a usare insieme file descriptor, metadati, directory e `stdio`, ma senza entrare ancora in processi e segnali.

Visto che hai già realizzato `mycp` e `tree`, eviterei l’ennesimo clone isolato di un comando Unix. Ti consiglierei un progetto più organico:

# `fsnap`: snapshot e verifica di un filesystem

Un programma che analizza ricorsivamente una directory, salva un’istantanea dei metadati e permette successivamente di rilevare che cosa è cambiato.

Esempio:

```bash
fsnap create ~/Projects snapshot.fsnap
fsnap list snapshot.fsnap
fsnap diff snapshot-old.fsnap snapshot-new.fsnap
fsnap verify snapshot.fsnap ~/Projects
```

È un progetto ideale per consolidare i primi cinque capitoli di APUE perché riunisce quasi tutti i concetti senza richiedere ancora processi, thread o segnali.

## Cosa dovrebbe registrare

Per ogni elemento:

```text
path
tipo di file
device ID
inode
permessi
numero di hard link
UID e GID
dimensione
ultimo accesso
ultima modifica
ultimo cambio dei metadati
destinazione del link simbolico
```

Un record potrebbe apparire così:

```text
F|src/main.c|2049|83124|0644|1|1000|1000|4821|1722410134
D|src|2049|83120|0755|2|1000|1000|4096|1722410100
L|current|2049|83130|0777|1|1000|1000|7|1722410150|release
```

Non partire subito da un formato binario. Un formato testuale è più facile da ispezionare, debuggare e leggere tramite `stdio`.

# Suddivisione del progetto

## Fase 1 — Esplorazione della directory

Implementa:

```bash
fsnap scan directory
```

Il programma deve attraversare ricorsivamente l’albero e stampare un record per ogni elemento.

Usa direttamente:

```c
opendir()
readdir()
closedir()
lstat()
readlink()
```

Non usare inizialmente `nftw()`: nasconderebbe proprio la parte che vuoi esercitare.

Questa fase consolida:

- costruzione corretta dei pathname;
- distinzione tra file regolari, directory e link simbolici;
- differenza tra `stat()` e `lstat()`;
- gestione di `.` e `..`;
- controllo sistematico di `errno`;
- ricorsione sulle directory.

Fai attenzione a non seguire accidentalmente i link simbolici, altrimenti puoi creare cicli.

## Fase 2 — Scrittura dello snapshot

Aggiungi:

```bash
fsnap create directory snapshot.fsnap
```

Apri il file di output tramite `fopen()` e scrivi i record con `fprintf()`.

Qui devi usare deliberatamente la libreria standard I/O:

```c
FILE *
fopen()
fprintf()
fclose()
fflush()
ferror()
```

Gestisci anche il caso in cui la scrittura fallisca durante `fclose()`: è un dettaglio spesso ignorato, ma importante perché l’errore potrebbe emergere soltanto quando il buffer viene scaricato.

Puoi sperimentare con:

```c
setvbuf()
```

provando buffering completo, line buffering e assenza di buffering.

## Fase 3 — Lettura e validazione

Implementa:

```bash
fsnap list snapshot.fsnap
```

Non limitarti a stampare le righe. Scrivi un vero parser che trasformi ogni riga in una struttura:

```c
struct snapshot_entry {
    char *path;
    mode_t mode;
    dev_t device;
    ino_t inode;
    nlink_t links;
    uid_t uid;
    gid_t gid;
    off_t size;
    struct timespec mtime;
    char *symlink_target;
};
```

Usa:

```c
getline()
strtol()
strtoull()
ferror()
feof()
```

Qui puoi esercitarti a distinguere correttamente:

```c
fine del file
errore di lettura
record malformato
valore fuori intervallo
```

È un ottimo punto per capire perché un parser robusto non può affidarsi soltanto a `sscanf()`.

## Fase 4 — Confronto tra snapshot

Implementa:

```bash
fsnap diff old.fsnap new.fsnap
```

Output possibile:

```text
A  src/new_file.c
D  src/old_file.c
M  src/main.c
P  scripts/build.sh
L  current
```

Dove:

```text
A = aggiunto
D = eliminato
M = contenuto o dimensione modificati
P = permessi modificati
L = destinazione del link simbolico modificata
```

Per la prima versione puoi conservare tutti i record in memoria e ordinarli per pathname con `qsort()`.

Il confronto dovrebbe separare le modifiche:

```text
pathname
tipo
dimensione
mtime
permessi
proprietario
destinazione del link
```

Questo ti obbliga a ragionare davvero sul significato dei campi di `struct stat`, invece di stamparli soltanto.

## Fase 5 — Verifica del filesystem reale

Aggiungi:

```bash
fsnap verify snapshot.fsnap directory
```

Il programma legge lo snapshot e confronta ogni record con il filesystem attuale.

Deve distinguere almeno:

```text
file mancante
tipo cambiato
permessi cambiati
dimensione cambiata
mtime cambiato
link simbolico cambiato
errore di accesso
```

Non trattare automaticamente tutti gli errori come “file inesistente”. Per esempio:

```c
ENOENT
EACCES
ENOTDIR
ELOOP
```

hanno significati molto diversi.

# Estensioni particolarmente utili

## Rilevamento degli hard link

Due pathname sono hard link dello stesso file quando condividono:

```text
st_dev
st_ino
```

Non basta confrontare soltanto l’inode, perché inode uguali possono esistere su filesystem differenti.

Puoi produrre un output come:

```text
H  documents/report.txt -> archive/report-copy.txt
```

Questo esercizio rende concreti inode, directory entry e link count.

## Rilevamento dei file sparsi

Confronta:

```c
st_size
st_blocks * 512
```

Un file può avere una dimensione logica molto maggiore dello spazio fisicamente allocato.

Aggiungi eventualmente:

```bash
fsnap sparse directory
```

È un piccolo esercizio molto APUE: semplice da implementare, ma concettualmente importante.

## Hash opzionale dei file

In una fase successiva puoi calcolare un hash dei file regolari:

```bash
fsnap create --hash directory snapshot.fsnap
```

Non serve partire da SHA-256. Per esercitarti con `read()`, può bastare inizialmente FNV-1a o CRC32.

Qui usa volutamente le system call non bufferizzate:

```c
open()
read()
close()
```

In questo modo il progetto contiene sia raw I/O sia standard I/O:

- `read()` per leggere il contenuto dei file;
- `stdio` per serializzare e analizzare lo snapshot.

# Collegamento con i capitoli di APUE

| Capitolo | Applicazione nel progetto |
|---|---|
| 1 — UNIX overview | file descriptor, errori, pathname, convenzioni Unix |
| 2 — standard e implementazioni | tipi POSIX, feature-test macro, portabilità |
| 3 — File I/O | `open`, `read`, `close`, `lseek`, descriptor |
| 4 — File e directory | `stat`, inode, permessi, link, tempi, directory |
| 5 — Standard I/O | `FILE`, buffering, `getline`, `fprintf`, errori stream |

Il capitolo 2 può sembrare meno “programmabile”, ma puoi applicarlo evitando tipi primitivi sbagliati. Per esempio, non assumere che `off_t`, `ino_t` o `time_t` siano `long`: converti e serializza con attenzione.

# Vincoli che ti consiglio di imporre

Per renderlo un vero esercizio di sistema:

- compilazione con `-std=c11 -Wall -Wextra -Wpedantic -Wconversion`;
- nessuna funzione che ignori il valore di ritorno;
- messaggi diagnostici su `stderr`;
- dati normali su `stdout`;
- exit status differenti per uso errato, errore I/O e snapshot non valido;
- nessun limite fisso arbitrario per la lunghezza dei pathname;
- test con file, directory, FIFO, symlink, hard link e file sparsi;
- test sotto Valgrind e sanitizers.

Una struttura sensata potrebbe essere:

```text
fsnap/
├── Makefile
├── src/
│   ├── main.c
│   ├── walk.c
│   ├── snapshot.c
│   ├── parser.c
│   ├── compare.c
│   └── errors.c
├── include/
│   └── fsnap.h
└── tests/
    ├── test-parser.c
    └── fixtures.sh
```

# Ordine di lavoro consigliato

Procederei così:

```text
1. scan e stampa dei metadati
2. create dello snapshot
3. parser e list
4. diff tra due snapshot
5. verify sul filesystem
6. hard link e symlink
7. file sparsi
8. hash dei contenuti
```

Il primo traguardo completo dovrebbe essere:

```bash
mkdir -p test/a
echo hello > test/a/file
ln test/a/file test/hardlink
ln -s a/file test/symlink

./fsnap create test before.fsnap

chmod 600 test/a/file
echo world >> test/a/file
rm test/symlink

./fsnap create test after.fsnap
./fsnap diff before.fsnap after.fsnap
```

Questo progetto è più formativo di un singolo clone di `ls` perché ti costringe a collegare il modello logico del filesystem Unix alle API concrete. Inoltre potrai estenderlo naturalmente più avanti: dopo i capitoli sui processi potrai parallelizzare l’hashing con worker process; dopo i segnali potrai gestire interruzioni e cleanup; dopo IPC potrai trasformarlo in un piccolo demone di indicizzazione.

## Utente — 2026-07-31 14:39

mi puoi dare una breve descrizione in inglese di questo progetto?

## ChatGPT — 2026-07-31 14:40

:::writing{variant="document" id="48317"}
**fsnap** is a command-line tool written in C that creates snapshots of directory trees and detects filesystem changes over time. It records file metadata such as type, permissions, ownership, size, timestamps, inode information, hard links, and symbolic links. Snapshots can be listed, compared, and verified against the current filesystem state.

The project is designed to reinforce core Unix system programming concepts, including file descriptors, directory traversal, metadata handling, standard I/O, error management, and portable POSIX programming.
:::

## Utente — 2026-07-31 15:09

Convert to writing block

Come faccio a rendere il makefile in grado di vedere i file header presenti nella cartella include?

## ChatGPT — 2026-07-31 15:10

Devi aggiungere la directory `include/` al percorso di ricerca del preprocessore tramite l’opzione:

```make
-Iinclude
```

Conviene inserirla in `CPPFLAGS`, che è la variabile Make tradizionalmente usata per le opzioni del preprocessore.

```make
CC := cc

CPPFLAGS := -Iinclude
CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -Wconversion
LDFLAGS :=
LDLIBS :=

TARGET := fsnap

SOURCES := \
	src/main.c \
	src/walk.c \
	src/snapshot.c \
	src/parser.c \
	src/compare.c \
	src/errors.c

OBJECTS := $(SOURCES:.c=.o)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) $(LDLIBS) -o $@

src/%.o: src/%.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)
```

Nei file `.c` puoi quindi includere l’header così:

```c
#include "fsnap.h"
```

Il comando eseguito da Make sarà equivalente a:

```bash
cc -Iinclude -std=c11 -Wall -Wextra -c src/main.c -o src/main.o
```

## Dipendenze automatiche dagli header

Nel Makefile precedente, modificando `include/fsnap.h`, Make potrebbe non ricompilare automaticamente tutti i file `.c` che lo usano. Puoi risolvere aggiungendo:

```make
CPPFLAGS := -Iinclude -MMD -MP
```

e poi:

```make
DEPENDENCIES := $(OBJECTS:.o=.d)

-include $(DEPENDENCIES)
```

Il Makefile completo diventa:

```make
CC := cc

CPPFLAGS := -Iinclude -MMD -MP
CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -Wconversion
LDFLAGS :=
LDLIBS :=

TARGET := fsnap

SOURCES := \
	src/main.c \
	src/walk.c \
	src/snapshot.c \
	src/parser.c \
	src/compare.c \
	src/errors.c

OBJECTS := $(SOURCES:.c=.o)
DEPENDENCIES := $(OBJECTS:.o=.d)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) $(LDLIBS) -o $@

src/%.o: src/%.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

-include $(DEPENDENCIES)

clean:
	rm -f $(OBJECTS) $(DEPENDENCIES) $(TARGET)
```

Le opzioni:

```text
-MMD
```

generano un file `.d` con le dipendenze dagli header, mentre:

```text
-MP
```

evita alcuni errori quando un header viene eliminato o rinominato.

Così, se modifichi:

```text
include/fsnap.h
```

Make ricompilerà soltanto i file sorgenti che includono realmente quell’header.

## Utente — 2026-07-31 15:54

fscotto:~/Projects/fsnap <main:?> › make
cc  -Iinclude src/main.o  -o fsnap
/usr/bin/ld.bfd: src/main.o: in function `main':
main.c:(.text+0x6d): undefined reference to `scan'
collect2: error: ld returned 1 exit status
make: *** [Makefile:20: fsnap] Error 1

## ChatGPT — 2026-07-31 15:54

L’errore non riguarda gli header: è un errore di **linking**.

Il comando eseguito è:

```bash
cc -Iinclude src/main.o -o fsnap
```

Stai collegando soltanto `src/main.o`, ma la funzione `scan()` è probabilmente definita in un altro file, ad esempio `src/walk.c`. L’header dichiara la funzione, ma non contiene la sua implementazione.

Aggiungi tutti i sorgenti alla variabile `SOURCES`:

```make
CC := cc

CPPFLAGS := -Iinclude -MMD -MP
CFLAGS := -std=c11 -Wall -Wextra -Wpedantic -Wconversion

TARGET := fsnap

SOURCES := \
	src/main.c \
	src/walk.c

OBJECTS := $(SOURCES:.c=.o)
DEPENDENCIES := $(OBJECTS:.o=.d)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) $(LDLIBS) -o $@

src/%.o: src/%.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

-include $(DEPENDENCIES)

clean:
	rm -f $(OBJECTS) $(DEPENDENCIES) $(TARGET)
```

Dopo:

```bash
make clean
make
```

Il linking dovrebbe diventare:

```bash
cc src/main.o src/walk.o -o fsnap
```

Controlla anche che in `walk.c` la funzione sia definita senza `static`:

```c
int scan(const char *path)
{
    /* ... */
}
```

e che l’header contenga una dichiarazione coerente:

```c
#ifndef FSNAP_H
#define FSNAP_H

int scan(const char *path);

#endif
```

Una definizione come questa renderebbe invece `scan()` visibile soltanto dentro `walk.c`:

```c
static int scan(const char *path);
```

Il dettaglio decisivo è comunque già nell’output di Make: compare solo `src/main.o`, quindi l’object file contenente `scan()` non sta partecipando al linking.

## Utente — 2026-07-31 23:41

in che modo lo scan differenza i link dai file regolari?

## ChatGPT — 2026-07-31 23:41

Lo `scan` deve usare **`lstat()`**, non `stat()`.

```c
struct stat sb;

if (lstat(path, &sb) == -1) {
    perror(path);
    return -1;
}

if (S_ISREG(sb.st_mode)) {
    printf("file regolare: %s\n", path);
} else if (S_ISDIR(sb.st_mode)) {
    printf("directory: %s\n", path);
} else if (S_ISLNK(sb.st_mode)) {
    printf("link simbolico: %s\n", path);
}
```

La differenza importante è questa:

```c
stat(path, &sb);
```

segue il link simbolico e restituisce i metadati dell’oggetto puntato.

```c
lstat(path, &sb);
```

non segue il link e restituisce i metadati del link stesso.

Per esempio, con:

```bash
ln -s file.txt link.txt
```

usando `stat("link.txt", ...)`, se `file.txt` è regolare:

```c
S_ISREG(sb.st_mode) == true
```

Usando `lstat("link.txt", ...)`:

```c
S_ISLNK(sb.st_mode) == true
```

Per leggere la destinazione del link usa `readlink()`:

```c
char target[4096];

ssize_t len = readlink(path, target, sizeof(target) - 1);

if (len == -1) {
    perror("readlink");
} else {
    target[len] = '\0';
    printf("%s -> %s\n", path, target);
}
```

`readlink()` non aggiunge automaticamente il terminatore `'\0'`, quindi devi farlo tu.

## Hard link

Un hard link è diverso: **non è un tipo di file separato**. Due hard link sono due pathname che fanno riferimento allo stesso inode.

```bash
ln original.txt copia.txt
```

Entrambi risultano file regolari:

```c
S_ISREG(sb.st_mode) == true
```

Per riconoscere che sono hard link dello stesso file devi confrontare:

```c
st_dev
st_ino
```

Per esempio:

```c
if (a.st_dev == b.st_dev && a.st_ino == b.st_ino) {
    printf("sono hard link dello stesso file\n");
}
```

Puoi anche osservare:

```c
sb.st_nlink
```

Se `st_nlink > 1`, l’inode ha più di un hard link, ma questo da solo non ti dice quali siano gli altri pathname.

Quindi, nello `scan`:

```c
if (S_ISLNK(sb.st_mode)) {
    /* symbolic link */
} else if (S_ISREG(sb.st_mode)) {
    /* regular file, eventualmente con più hard link */
}
```

Evita di basarti soltanto su `dirent.d_type`: su alcuni filesystem può valere `DT_UNKNOWN`. `lstat()` è il controllo affidabile.

## Utente — 2026-07-31 23:42

la mia implementazione di si basa su dirent.d_type ma gestisco solo i casi in cui siano directory o file regolari alla fine se sono link al momento faccio uno skip, ma lo potrei trattare sempre come un file regolare visto che non devo seguire i link

## ChatGPT — 2026-07-31 23:43

Puoi trattarlo come un elemento “foglia” durante la ricorsione, cioè come qualcosa dentro cui non devi entrare, ma **non come un file regolare** dal punto di vista semantico.

Un link simbolico è un tipo di file distinto:

```c
DT_REG  /* file regolare */
DT_DIR  /* directory */
DT_LNK  /* link simbolico */
```

Se non vuoi seguire i link, la logica può essere:

```c
switch (entry->d_type) {
case DT_DIR:
    /* entra ricorsivamente, tranne "." e ".." */
    break;

case DT_REG:
    /* registra metadati del file */
    break;

case DT_LNK:
    /* registra il link, ma non seguirlo */
    break;

default:
    /* FIFO, socket, device oppure DT_UNKNOWN */
    break;
}
```

Per un link simbolico dovresti registrare almeno:

- il pathname del link;
- il fatto che sia un link simbolico;
- la destinazione restituita da `readlink()`;
- eventualmente i metadati restituiti da `lstat()`.

Per esempio:

```c
struct stat st;

if (lstat(path, &st) == -1) {
    perror(path);
    return -1;
}

if (S_ISLNK(st.st_mode)) {
    char target[4096];

    ssize_t len = readlink(path, target, sizeof(target) - 1);
    if (len == -1) {
        perror("readlink");
        return -1;
    }

    target[len] = '\0';
    printf("L|%s|%s\n", path, target);
}
```

La distinzione è importante durante il confronto degli snapshot. Immagina:

```bash
ln -s version-1 current
```

e successivamente:

```bash
ln -sfn version-2 current
```

Il pathname `current` esiste ancora, ma il link è cambiato. Trattandolo come file regolare perderesti questa informazione oppure proveresti erroneamente a leggerne il contenuto seguendo il collegamento.

C’è inoltre un problema con `dirent.d_type`: non tutti i filesystem lo valorizzano. Può restituire:

```c
DT_UNKNOWN
```

Quindi una soluzione robusta è usare `d_type` soltanto come ottimizzazione e fare fallback su `lstat()`:

```c
if (entry->d_type == DT_UNKNOWN) {
    struct stat st;

    if (lstat(path, &st) == -1) {
        perror(path);
        return -1;
    }

    if (S_ISDIR(st.st_mode)) {
        /* directory */
    } else if (S_ISREG(st.st_mode)) {
        /* file regolare */
    } else if (S_ISLNK(st.st_mode)) {
        /* link simbolico */
    }
}
```

Nel caso di `fsnap`, userei una classificazione esplicita:

```text
D = directory
F = file regolare
L = link simbolico
P = FIFO
S = socket
B = block device
C = character device
```

Puoi quindi condividere parte del codice tra file regolari e link perché entrambi non richiedono ricorsione, ma mantieni distinto il tipo registrato nello snapshot.

## Utente — 2026-07-31 23:46

Si ok ma lo scan fa solo il walk della directory e li stampa a stdout per cui io ho fatto un algoritmo di walk del filesystem e poi dalla funzione esegue qualcosa , in questo caso in realtà a che serve sapere se è un link o meno? di fatto devo stampare solo il file come un file regolare qualsiasi. Nel caso di DT_UNKOWN quello userà un algoritmo di fallback  ti torna?

## ChatGPT — 2026-07-31 23:46

Sì, **il ragionamento torna**.

Nel tuo caso lo `scan` è essenzialmente un filesystem walker. Per decidere il flusso gli basta distinguere:

- directory → entra ricorsivamente;
- qualsiasi altra entry → esegue l’azione, cioè la stampa.

Quindi un link simbolico può seguire lo stesso ramo operativo di un file regolare, purché tu **non lo apra e non usi `stat()` per seguirne la destinazione**.

Per esempio:

```c
switch (entry->d_type) {
case DT_DIR:
    if (!is_dot_directory(entry->d_name)) {
        walk(path);
    }
    break;

case DT_UNKNOWN:
    handle_unknown(path);
    break;

default:
    printf("%s\n", path);
    break;
}
```

Qui il `default` comprende:

```text
DT_REG
DT_LNK
DT_FIFO
DT_SOCK
DT_CHR
DT_BLK
```

Dal punto di vista del walking sono tutti elementi foglia: li stampi, ma non ci entri.

## Fallback per `DT_UNKNOWN`

Anche questo approccio va bene:

```c
static int handle_unknown(const char *path)
{
    struct stat st;

    if (lstat(path, &st) == -1) {
        perror(path);
        return -1;
    }

    if (S_ISDIR(st.st_mode)) {
        return walk(path);
    }

    printf("%s\n", path);
    return 0;
}
```

È importante usare `lstat()` perché:

- se il pathname è un link a una directory, `lstat()` lo considera un link e non ci entri;
- `stat()` seguirebbe il link e potrebbe farti ricorrere nella directory puntata;
- un link spezzato viene comunque riconosciuto e stampato.

Quindi la distinzione non deve necessariamente essere:

```text
directory / file regolare / link
```

Per il tuo algoritmo può semplicemente essere:

```text
directory reale / elemento foglia
```

Un dettaglio: io non chiamerei internamente il secondo gruppo “file regolari”, perché include anche symlink, FIFO, socket e device. Un nome come `visit_entry()`, `process_entry()` oppure `visit_leaf()` descrive meglio ciò che sta facendo:

```c
if (is_directory) {
    walk(path);
} else {
    process_entry(path);
}
```

Quando passerai alla creazione dello snapshot, allora il callback dovrà distinguere i tipi, perché vorrai registrare informazioni differenti. Ma per il comando `scan`, che stampa soltanto i pathname, trattare il link come qualsiasi altra entry non-directory è perfettamente sensato.

## Utente — 2026-08-01 00:07

ok ho visto che il codice funziona anche su NetBSD per cui posso passare al punto 2 dell'esercizio

## ChatGPT — 2026-08-01 00:07

Ottimo: il fatto che funzioni anche su NetBSD è già un buon segnale che il walker non dipende troppo da dettagli Linux-specifici.

Per il **punto 2**, trasformerei lo `scan` in:

```bash
./fsnap create directory snapshot.fsnap
```

L’obiettivo ora è riutilizzare lo stesso walker, ma invece di stampare semplicemente i pathname, scrivere un record per ogni entry.

## Primo passo: separare walk e operazione

Una struttura utile è questa:

```c
typedef int (*visitor_fn)(const char *path, void *context);

int walk_directory(const char *path, visitor_fn visitor, void *context);
```

Il walker si occupa solo di:

- attraversare le directory;
- costruire i pathname;
- non seguire i symlink;
- invocare il visitor su ogni entry.

Lo `scan` può usare:

```c
static int print_entry(const char *path, void *context)
{
    (void) context;

    puts(path);
    return 0;
}
```

Mentre `create` userà:

```c
static int write_snapshot_entry(const char *path, void *context)
{
    FILE *snapshot = context;

    /* lstat() e fprintf() */

    return 0;
}
```

Questa separazione è importante: non devi duplicare il traversal quando aggiungerai `create`, `verify` o altre operazioni.

## Formato minimo iniziale

Parti con pochi campi:

```text
tipo|permessi|uid|gid|dimensione|mtime|path
```

Esempio:

```text
F|0644|1000|1000|125|1753999812|src/main.c
D|0755|1000|1000|512|1753999700|src
L|0777|1000|1000|8|1753999600|current
```

Per ora puoi usare:

```c
struct stat st;

if (lstat(path, &st) == -1) {
    /* errore */
}
```

Il tipo può essere ricavato così:

```c
static char file_type(mode_t mode)
{
    if (S_ISREG(mode))
        return 'F';
    if (S_ISDIR(mode))
        return 'D';
    if (S_ISLNK(mode))
        return 'L';
    if (S_ISFIFO(mode))
        return 'P';
    if (S_ISCHR(mode))
        return 'C';
    if (S_ISBLK(mode))
        return 'B';
    if (S_ISSOCK(mode))
        return 'S';

    return '?';
}
```

## Scrittura del record

Una prima versione può essere:

```c
static int write_snapshot_entry(const char *path, void *context)
{
    FILE *snapshot = context;
    struct stat st;

    if (lstat(path, &st) == -1) {
        perror(path);
        return -1;
    }

    if (fprintf(snapshot,
                "%c|%04o|%ju|%ju|%jd|%jd|%s\n",
                file_type(st.st_mode),
                (unsigned int) (st.st_mode & 07777),
                (uintmax_t) st.st_uid,
                (uintmax_t) st.st_gid,
                (intmax_t) st.st_size,
                (intmax_t) st.st_mtime,
                path) < 0) {
        perror("fprintf");
        return -1;
    }

    return 0;
}
```

Servono:

```c
#include <inttypes.h>
#include <stdio.h>
#include <sys/stat.h>
```

L’uso di `intmax_t` e `uintmax_t` evita di assumere che tipi come `off_t`, `uid_t` e `time_t` corrispondano sempre a `long`. È particolarmente sensato visto che stai già provando il programma su sistemi diversi.

## Implementazione del comando

La funzione `create_snapshot()` potrebbe essere:

```c
int create_snapshot(const char *directory, const char *output_path)
{
    FILE *snapshot;
    int result;

    snapshot = fopen(output_path, "w");
    if (snapshot == NULL) {
        perror(output_path);
        return -1;
    }

    result = walk_directory(directory, write_snapshot_entry, snapshot);

    if (fclose(snapshot) == EOF) {
        perror(output_path);
        return -1;
    }

    return result;
}
```

Controllare `fclose()` è importante: una scrittura bufferizzata può fallire soltanto quando il buffer viene effettivamente scaricato.

## Attenzione al file snapshot

Se crei lo snapshot dentro la directory che stai scansionando:

```bash
./fsnap create . snapshot.fsnap
```

il walker potrebbe incontrare anche il file che sta scrivendo.

Per la prima versione hai tre possibilità:

1. documentare che il file di output deve stare fuori dalla directory;
2. saltare esplicitamente il pathname dello snapshot;
3. scrivere prima in un file temporaneo esterno.

Per adesso sceglierei la prima, perché mantiene semplice l’esercizio:

```bash
./fsnap create test /tmp/test.fsnap
```

## Criterio di completamento del punto 2

Considererei completata questa fase quando funziona questo test:

```bash
mkdir -p test/subdir
printf 'hello\n' > test/file.txt
ln test/file.txt test/hardlink.txt
ln -s file.txt test/symlink

./fsnap create test test.fsnap
cat test.fsnap
```

E nello snapshot compaiono:

- directory;
- file regolari;
- entrambi i pathname degli hard link;
- link simbolico come tipo `L`;
- permessi, UID, GID, dimensione e `mtime`.

Non occuparti ancora del parsing dello snapshot o del confronto: prima rendi solida la produzione del file.

## Utente — 2026-08-01 18:11

Dacci un occhio https://github.com/fscotto/fsnap

## ChatGPT — 2026-08-01 18:11

Guardo struttura, Makefile e implementazione del walker, poi ti segnalo subito eventuali problemi di portabilità o di design prima del punto 2.

La struttura è già buona: hai separato traversal, callback, `scan`, `create` e utility. Sto verificando soprattutto la gestione di `errno`, del temporaneo e degli errori di scrittura, dove in C si annidano i gremlin.

Sì: **il punto 2 è sostanzialmente completato**. La direzione architetturale è buona e, soprattutto, non hai duplicato il traversal.

Hai separato correttamente:

- `walk()` come meccanismo generico;
- una callback `operation`;
- `scan()` con callback di stampa;
- `create()` con callback di serializzazione;
- utility e header distinti.

È esattamente la separazione che cercavamo. `walk()` gestisce inoltre `DT_UNKNOWN` tramite `lstat()` e non segue i link simbolici, quindi il comportamento è coerente anche sui filesystem che non valorizzano `d_type`. citeturn926088view1

## Correzioni importanti prima del punto 3

### 1. Controlla il risultato di `fprintf()`

In `write_record()` ignori il valore restituito:

```c
fprintf(snapshot, "%c|%04o|%ju|%ju|%jd|%jd|%s\n",
        type, perm, uid, gid, size, time, path);

return 0;
```

Se la scrittura fallisce, la callback comunica comunque successo. citeturn926088view3

Meglio:

```c
if (fprintf(snapshot,
            "%c|%04o|%ju|%ju|%jd|%jd|%s\n",
            type,
            perm,
            uid,
            gid,
            size,
            time,
            path) < 0) {
    return -1;
}

return 0;
```

Il successivo `fflush()` è comunque corretto e va mantenuto.

### 2. Hai un file descriptor leak se `fdopen()` fallisce

Qui:

```c
int fd = mkstemp(template);

FILE *tmp = fdopen(fd, "w+");

if (tmp == NULL) {
    rc = -1;
    goto out;
}
```

se `fdopen()` fallisce, `tmp` rimane `NULL`, quindi nel cleanup non viene eseguito `fclose()`, ma `fd` è ancora aperto. citeturn926088view3

Correzione minima:

```c
FILE *tmp = fdopen(fd, "w+");

if (tmp == NULL) {
    int saved_errno = errno;
    close(fd);
    unlink(template);
    free(resolved);
    errno = saved_errno;
    return -1;
}
```

In alternativa inizializza `fd = -1` e gestiscilo centralmente nel blocco di cleanup.

### 3. `copy()` può lasciare aperto il file di destinazione

Alla fine hai:

```c
if (fclose(file1) != 0)
    return -1;

if (fclose(file2) != 0)
    return -1;
```

Se la chiusura di `file1` fallisce, ritorni immediatamente e `file2` resta aperto. citeturn926088view0

Una versione minima più robusta è:

```c
int rc = 0;

if (fclose(file1) != 0)
    rc = -1;

if (fclose(file2) != 0)
    rc = -1;

return rc;
```

Per una gestione impeccabile dovresti anche preservare il primo `errno`, ma puoi farlo in un refactoring successivo.

### 4. Il formato non supporta tutti i nomi validi Unix

Il record usa:

```text
tipo|permessi|uid|gid|dimensione|mtime|path
```

ma un pathname Unix può contenere sia `|` sia newline. Quando scriverai il parser del punto 3, un file chiamato:

```bash
touch 'uno|due'
```

renderà ambiguo il record.

Hai tre possibilità:

1. documentare temporaneamente che questi nomi non sono supportati;
2. effettuare escaping di `\`, `|` e newline;
3. usare campi con lunghezza esplicita.

Per l’esercizio sceglierei l’escaping:

```text
\  -> \\
|  -> \|
LF -> \n
```

La cosa importante è decidere **prima** di scrivere il parser.

## Due scelte da rivedere, ma non bloccanti

### Non saltare tutti i file `.fsnap`

Attualmente salti qualunque entry il cui nome termini con `.fsnap`, senza verificare che sia davvero il file di output. citeturn926088view3

```c
if (n >= 6 && strcasecmp(base + n - 6, ".fsnap") == 0)
    return 0;
```

Questo significa che una directory contenente vecchi snapshot verrà rappresentata in modo incompleto. Inoltre stai già scrivendo prima in `/tmp`, quindi il nuovo snapshot non viene incontrato durante il traversal.

Per ora eliminerei completamente questo filtro. In seguito potrai escludere **soltanto l’esatto file di output**, se già esistente e collocato nell’albero scansionato.

Nota minore: `strcasecmp()` va dichiarata includendo:

```c
#include <strings.h>
```

non soltanto `<string.h>`.

### Valuta pathname relativi nello snapshot

`resolve_path()` usa `realpath()`, quindi lo snapshot contiene pathname assoluti. citeturn926088view0turn926088view3

Questo funziona, ma rende lo snapshot legato alla posizione attuale:

```text
/home/fscotto/Projects/fsnap/src/main.c
```

Per `diff` e `verify` è generalmente più pratico salvare:

```text
src/main.c
```

e conservare separatamente la root dello snapshot. Non devi sistemarlo necessariamente subito, ma conviene deciderlo prima di implementare il parser.

## Test che farei adesso

```bash
mkdir -p /tmp/fsnap-test/subdir
printf 'hello\n' > /tmp/fsnap-test/file.txt
ln /tmp/fsnap-test/file.txt /tmp/fsnap-test/hardlink.txt
ln -s file.txt /tmp/fsnap-test/link.txt
ln -s missing.txt /tmp/fsnap-test/broken-link
mkfifo /tmp/fsnap-test/pipe
touch '/tmp/fsnap-test/file|with|pipes'

./build/fsnap scan /tmp/fsnap-test
./build/fsnap create /tmp/fsnap-test /tmp/test.fsnap
cat /tmp/test.fsnap
```

Verifica che:

- il link a directory non venga seguito;
- il broken symlink venga registrato;
- la FIFO sia marcata `P`;
- i due hard link abbiano due record;
- un errore di scrittura faccia fallire `create`;
- il pathname con `|` evidenzi il limite del formato.

## Giudizio finale

**Promosso per il punto 2**, con tre bug concreti da correggere subito:

1. risultato di `fprintf()` non controllato;
2. `fd` non chiuso se `fdopen()` fallisce;
3. `file2` non chiuso se il primo `fclose()` fallisce.

Dopo queste correzioni passerei al punto 3: struttura `snapshot_entry`, lettura con `getline()` e parser del record. Prima, però, fisserei formalmente il formato dello snapshot: è il contratto su cui poggerà tutto il resto.

## Utente — 2026-08-01 19:29

questo mi da sempre bad descriptor, non sarà perche'il file di mkstemp è opaco?

## ChatGPT — 2026-08-01 19:29

No, il file creato da `mkstemp()` non è “opaco”: restituisce un normale file descriptor Unix.

Il punto è che **`fdopen()` trasferisce di fatto la gestione del descriptor allo stream `FILE *`**. Dopo che `fdopen()` ha avuto successo, devi chiudere lo stream con `fclose()`, non anche il descriptor con `close()`.

Quindi:

```c
int fd = mkstemp(template);
if (fd == -1)
    return -1;

FILE *tmp = fdopen(fd, "w+");
if (tmp == NULL) {
    int saved_errno = errno;

    close(fd);          /* corretto: fdopen è fallita */
    unlink(template);

    errno = saved_errno;
    return -1;
}

/* Da qui in poi fd appartiene a tmp. */

if (fclose(tmp) == EOF)
    return -1;

/* Non fare close(fd): fclose lo ha già chiuso. */
```

Se fai:

```c
fclose(tmp);
close(fd);
```

il secondo comando fallisce con:

```text
EBADF: Bad file descriptor
```

perché `fclose(tmp)` internamente ha già chiuso `fd`.

## Pattern sicuro con cleanup centralizzato

Se hai un blocco `goto out`, puoi impostare `fd = -1` dopo `fdopen()`:

```c
int fd = -1;
FILE *tmp = NULL;
int rc = -1;

fd = mkstemp(template);
if (fd == -1)
    goto out;

tmp = fdopen(fd, "w+");
if (tmp == NULL)
    goto out;

/*
 * Il descriptor adesso è posseduto da tmp.
 * Evitiamo che il cleanup lo chiuda una seconda volta.
 */
fd = -1;

/* operazioni sul file */

rc = 0;

out:
{
    int saved_errno = errno;

    if (tmp != NULL) {
        if (fclose(tmp) == EOF)
            rc = -1;
    } else if (fd != -1) {
        close(fd);
    }

    errno = saved_errno;
}

return rc;
```

La regola pratica è:

```text
mkstemp() riuscita, fdopen() fallita  -> close(fd)
fdopen() riuscita                     -> fclose(stream)
```

Mai entrambi sullo stesso descriptor.

## Utente — 2026-08-01 22:02

dai un altro sguardo al repo dovrei aver risolto tutto

## ChatGPT — 2026-08-01 22:02

Ricontrollo l’ultima versione del repository, soprattutto `create.c`, `utility.c`, il cleanup dei file descriptor e il formato dello snapshot.

Le tre correzioni principali ci sono: ora controlli `fprintf()`, chiudi `fd` solo se `fdopen()` fallisce e `copy()` tenta entrambe le `fclose()`. Faccio anche una compilazione e qualche test d’errore, perché il cleanup è corretto sulla carta ma `errno` può ancora fare scherzi.

Sì: **le tre correzioni che avevamo individuato sono state applicate correttamente**.

- `write_record()` ora controlla il risultato di `fprintf()` e restituisce `-1` in caso di errore. citeturn951766view0L32-L56
- Se `fdopen()` fallisce, chiudi il descriptor ottenuto da `mkstemp()`; se invece riesce, il descriptor viene chiuso soltanto tramite `fclose(tmp)`. Quindi non vedo più il double-close che provocava `EBADF`. citeturn951766view0L73-L85
- `copy()` prova a chiudere entrambi gli stream anche se la prima `fclose()` fallisce. citeturn150543view1L72-L78

Anche il Makefile è impostato bene: object separati nella directory `build/`, dipendenze automatiche `.d` e header cercati tramite `-Iinclude`. citeturn465344view0L0-L39

## Cose ancora da sistemare

Non sono bloccanti per considerare completata la versione base del punto 2, ma non direi ancora “tutto”.

### 1. Stai ancora ignorando tutti i file `.fsnap`

```c
if (n >= 6 && strcasecmp(base + n - 6, ".fsnap") == 0)
    return 0;
```

Così non escludi soltanto il file di output: escludi qualunque file con quell’estensione presente nell’albero. citeturn951766view0L32-L38

Dato che il file temporaneo viene creato in `/tmp`, per ora eliminerei completamente questo filtro. Il nuovo snapshot non si trova nella directory durante il walk.

Resta il caso di un vecchio file di output già esistente dentro la directory. Puoi semplicemente documentare per questa fase che l’output deve stare fuori dall’albero:

```bash
fsnap create test /tmp/test.fsnap
```

### 2. Preserva `errno` durante il cleanup

Supponiamo che `walk()` fallisca con `EACCES`. Successivamente esegui:

```c
free(resolved);
unlink(template);
fclose(tmp);
```

Una di queste operazioni potrebbe cambiare `errno`, per cui `main()` potrebbe stampare una causa diversa dall’errore originale. Il flusso di cleanup è corretto, ma il diagnostico non è ancora completamente robusto. citeturn951766view0L87-L108

Puoi usare:

```c
out:
{
    int saved_errno = errno;

    free(resolved);

    if (unlink(template) == -1 && rc == 0) {
        saved_errno = errno;
        rc = -1;
    }

    if (tmp != NULL && fclose(tmp) != 0 && rc == 0) {
        saved_errno = errno;
        rc = -1;
    }

    errno = saved_errno;
    return rc;
}
```

Nel caso `fdopen()` fallisca, però, devi salvare `errno` **prima** di `close(fd)`:

```c
if (tmp == NULL) {
    int saved_errno = errno;
    close(fd);
    errno = saved_errno;
    rc = -1;
    goto out;
}
```

### 3. Anche `copy()` può perdere l’errore originale

Per esempio:

```c
if (fwrite(...) != bytes) {
    fclose(file1);
    fclose(file2);
    return -1;
}
```

Le due `fclose()` possono sostituire l’`errno` prodotto da `fwrite()`. citeturn150543view1L56-L69

Qui basta:

```c
if (fwrite(buffer, 1, bytes, file2) != bytes) {
    int saved_errno = errno;
    fclose(file1);
    fclose(file2);
    errno = saved_errno;
    return -1;
}
```

È una rifinitura da system programming più che un problema funzionale immediato.

## Sul walker

Il walker continua a essere ben impostato:

- usa `d_type` quando disponibile;
- fa fallback con `lstat()` per `DT_UNKNOWN`;
- non ricorre nei link simbolici;
- libera il pathname anche sui percorsi d’errore;
- controlla `readdir()` distinguendo fine directory ed errore tramite `errno`. citeturn150543view2L19-L89

Una piccola aggiunta: in `scan.c` anche `printf()` dovrebbe essere controllata, per coerenza con `fprintf()`:

```c
static int print_file(const char *file, void *context)
{
    (void)context;
    return printf("[%s]\n", file) < 0 ? -1 : 0;
}
```

Attualmente restituisce sempre successo. citeturn150543view4L9-L13

## Verdetto

**Il bug del bad file descriptor è risolto e la gestione fondamentale delle risorse ora torna.** Per la versione base di `create`, puoi considerare il punto 2 completato dopo aver rimosso il filtro globale sui `.fsnap`.

Prima di iniziare il parser del punto 3, resta da decidere come rappresentare pathname contenenti `|` o newline e se salvare anche il target dei link simbolici. Quello è il momento giusto per congelare formalmente il formato del file.

## Utente — 2026-08-02 10:24

In cosa consiste il punto 3? Non darmi il codice già fatto

## ChatGPT — 2026-08-02 10:24

Il **punto 3** consiste nel fare il percorso inverso rispetto a `create`:

> leggere uno snapshot `.fsnap`, interpretare ogni record e trasformarlo in una struttura dati utilizzabile dal programma.

Non devi ancora confrontare due snapshot. Devi solo costruire un parser affidabile.

## Obiettivo pratico

Aggiungere un comando del tipo:

```bash
fsnap list snapshot.fsnap
```

che:

1. apre il file;
2. legge una riga alla volta;
3. separa i campi;
4. converte i valori testuali nei tipi corretti;
5. valida il record;
6. stampa i dati in forma leggibile.

Il punto importante non è la stampa: è il parsing.

## Struttura da progettare

Dovresti rappresentare ogni record con una struttura simile concettualmente a:

```text
snapshot_entry
├── tipo
├── permessi
├── uid
├── gid
├── dimensione
├── mtime
└── pathname
```

Non serve copiare questa forma alla lettera. L’esercizio è anche decidere quali tipi C usare e chi possiede la memoria del pathname.

## Problemi che devi affrontare

### Lettura delle righe

Devi leggere record di lunghezza arbitraria, quindi evita buffer fissi come:

```c
char line[1024];
```

Il pathname potrebbe essere più lungo.

### Separazione dei campi

Dato un record come:

```text
F|0644|1000|1000|125|1753999812|src/main.c
```

devi riconoscere esattamente sette campi e rilevare casi come:

```text
F|0644|1000
```

oppure:

```text
F|0644|abc|1000|125|1753999812|src/main.c
```

### Conversione numerica

Non basta usare funzioni permissive senza controlli. Devi distinguere:

- numero valido;
- campo vuoto;
- caratteri residui;
- overflow;
- valore negativo quando non ammesso.

Questo è uno dei punti didatticamente più importanti.

### Validazione semantica

Un record può essere sintatticamente leggibile ma comunque invalido.

Esempi:

```text
X|0644|1000|1000|125|1753999812|file
```

Tipo sconosciuto.

```text
F|9999|1000|1000|125|1753999812|file
```

Permessi non validi.

```text
F|0644|1000|1000|-12|1753999812|file
```

Dimensione negativa per un file regolare.

Devi decidere quali controlli appartengono al parser e quali lasciare alle fasi successive.

## Gestione degli errori

Il comando dovrebbe distinguere almeno:

- impossibile aprire il file;
- errore durante la lettura;
- snapshot malformato;
- errore di memoria;
- errore durante la stampa.

Un messaggio utile dovrebbe indicare anche la riga:

```text
snapshot.fsnap:12: invalid uid
```

Questo ti obbliga a mantenere un contatore delle righe.

## Domanda progettuale fondamentale

Devi decidere come gestire pathname contenenti il separatore `|` o newline.

Con il formato attuale, un pathname come:

```text
notes|old.txt
```

rende ambiguo il parsing.

Prima di implementare il parser, scegli una strategia:

- escaping;
- lunghezza esplicita del pathname;
- formato temporaneamente limitato e documentato.

Per questo esercizio, l’escaping è probabilmente la scelta più interessante.

## Quando il punto 3 è completo

Puoi considerarlo finito quando:

```bash
fsnap list valid.fsnap
```

legge correttamente tutti i record, mentre file malformati come questi vengono rifiutati con un errore preciso:

```text
F|0644|1000
F|hello|1000|1000|12|123|file
Q|0644|1000|1000|12|123|file
F|0644|1000|1000|12|123|
```

In sostanza, il punto 2 produce il formato; il punto 3 dimostra che il formato è realmente ben definito e leggibile. È il passaggio che prepara `diff` e `verify`.

## Utente — 2026-08-15 15:45

generami un markdown con le specifiche di questo progetto

## ChatGPT — 2026-08-15 15:45

:::writing{variant="document" id="58314"}
# fsnap — Project Specification

## 1. Overview

`fsnap` is a small POSIX command-line utility written in C for exploring filesystem and Unix system-programming concepts.

The program recursively walks a directory tree, creates textual snapshots of filesystem metadata, reads and validates existing snapshots, compares snapshots, and verifies them against the current filesystem state.

The project is intentionally designed around low-level POSIX and C standard-library APIs rather than high-level filesystem abstractions.

---

## 2. Goals

The main goals of the project are to practice:

- filesystem traversal;
- file and directory metadata;
- file descriptors;
- standard I/O streams;
- symbolic and hard links;
- POSIX data types;
- error handling with `errno`;
- portable Unix programming;
- resource management;
- parsing textual data;
- designing reusable C interfaces.

The implementation should remain reasonably portable across POSIX systems such as Linux and NetBSD.

---

## 3. Non-Goals

The initial version does not aim to provide:

- filesystem monitoring;
- real-time change detection;
- process parallelism;
- threads;
- cryptographic integrity guarantees;
- compression;
- network synchronization;
- platform-specific filesystem features.

These may be explored later as optional extensions.

---

# 4. Commands

## 4.1 `scan`

```text
fsnap scan <directory>
```

Recursively walks the specified directory and prints every discovered filesystem entry to standard output.

### Requirements

The walker must:

- recursively enter real directories;
- ignore `.` and `..`;
- not follow symbolic links;
- process non-directory entries as leaves;
- support filesystems where `dirent.d_type` is unavailable;
- use `lstat()` as a fallback when `d_type == DT_UNKNOWN`;
- propagate traversal and callback errors to the caller.

The traversal mechanism should be independent from the operation performed on each entry.

Conceptually:

```text
walk(directory, operation, context)
```

This allows the same walker to be reused by commands such as `scan` and `create`.

---

# 5. Snapshot Creation

## 5.1 `create`

```text
fsnap create <directory> <snapshot>
```

Creates a textual snapshot representing the state of the specified directory tree.

The command must reuse the generic filesystem walker.

For every discovered entry, the program obtains metadata using `lstat()` and serializes it into the snapshot.

---

## 5.2 Snapshot Entry

Each snapshot record should contain at least:

```text
type
permissions
uid
gid
size
mtime
path
```

Example conceptual representation:

```text
F|0644|1000|1000|125|1753999812|src/main.c
D|0755|1000|1000|512|1753999700|src
L|0777|1000|1000|8|1753999600|current
```

The exact serialization format is part of the project specification and should remain stable once the parser is implemented.

---

## 5.3 File Types

Filesystem entries should be represented explicitly.

Suggested identifiers:

```text
F = regular file
D = directory
L = symbolic link
P = FIFO
S = socket
C = character device
B = block device
? = unknown or unsupported type
```

The filesystem walker itself does not necessarily need to distinguish all of these types.

For traversal purposes, the important distinction is:

```text
directory
non-directory entry
```

The snapshot writer is responsible for determining the specific entry type.

---

# 6. Symbolic Links

Symbolic links must not be followed during traversal.

`lstat()` must therefore be used when metadata about an entry is required.

A symbolic link must be represented as a symbolic link rather than as the object it references.

A later version of the snapshot format should also store the link target obtained using:

```text
readlink()
```

Broken symbolic links must still be representable in a snapshot.

---

# 7. Hard Links

Hard links are not a separate filesystem object type.

Two paths refer to the same filesystem object when both their:

```text
st_dev
st_ino
```

values match.

Future versions of the snapshot format may store:

```text
device ID
inode number
link count
```

to allow hard-link relationships to be detected.

---

# 8. Snapshot Writing

Snapshot output must use standard C I/O streams.

Relevant APIs include:

```text
fopen()
fdopen()
fprintf()
fflush()
fclose()
```

All operations capable of failing must have their return values checked.

In particular, errors from:

```text
fprintf()
fflush()
fclose()
```

must not be ignored.

A buffered write may succeed initially and fail only when the stream is flushed or closed.

---

# 9. Temporary Files

Snapshot generation may use a temporary file created using:

```text
mkstemp()
```

`mkstemp()` returns an open file descriptor.

The descriptor may then be associated with a `FILE *` stream using:

```text
fdopen()
```

Ownership rules must be respected:

```text
mkstemp succeeds + fdopen fails
    -> close(fd)

fdopen succeeds
    -> fclose(stream)
```

The same descriptor must never be closed twice.

Temporary files must be removed during cleanup when no longer required.

---

# 10. Error Handling

Errors should be propagated rather than silently ignored.

The program should use:

```text
0
```

for successful operations and a non-zero result for failures.

Library-style internal functions should generally return:

```text
0
```

on success and:

```text
-1
```

on failure where appropriate.

Diagnostic output should be written to:

```text
stderr
```

while normal command output should be written to:

```text
stdout
```

When cleanup operations occur after an error, the original `errno` should be preserved whenever possible.

---

# 11. Resource Management

Every acquired resource must have a clearly defined owner.

Resources include:

- dynamically allocated memory;
- directory streams;
- file descriptors;
- `FILE *` streams;
- temporary files.

Every successful:

```text
malloc()
opendir()
open()
mkstemp()
fopen()
```

must eventually have a corresponding cleanup operation.

Cleanup must also occur on error paths.

---

# 12. Snapshot Parser

## 12.1 `list`

```text
fsnap list <snapshot>
```

Reads and validates an existing snapshot.

The main purpose of this command is to implement a robust parser for the snapshot format.

The parser should transform each textual record into an internal structure representing one snapshot entry.

Conceptually:

```text
snapshot_entry
├── type
├── permissions
├── uid
├── gid
├── size
├── modification time
└── path
```

The exact C structure is intentionally left as an implementation decision.

---

# 13. Reading Snapshot Records

Records must be read without assuming an arbitrary fixed maximum line length.

The parser should therefore use dynamically sized input rather than constructs such as:

```text
char line[1024]
```

POSIX facilities such as `getline()` are appropriate.

The program must distinguish:

- successful read;
- end of file;
- I/O error;
- malformed record.

---

# 14. Numeric Parsing

Numeric fields must be validated carefully.

The parser must detect:

- empty numeric fields;
- invalid characters;
- trailing characters;
- negative values where forbidden;
- values outside the representable range;
- integer overflow and underflow.

Functions such as:

```text
strtol()
strtoul()
strtoimax()
strtoumax()
```

may be used with appropriate validation.

The parser must not assume that POSIX types such as:

```text
uid_t
gid_t
off_t
time_t
ino_t
```

are equivalent to a specific primitive C type.

---

# 15. Record Validation

The parser must reject malformed records.

Examples include:

```text
F|0644|1000
```

Missing fields.

```text
F|hello|1000|1000|12|123|file
```

Invalid permissions.

```text
X|0644|1000|1000|12|123|file
```

Unknown file type.

```text
F|0644|1000|1000|-10|123|file
```

Invalid size for a regular file.

Errors should preferably identify the offending snapshot and line number.

Example:

```text
snapshot.fsnap:17: invalid uid
```

---

# 16. Path Encoding

Unix filenames may contain almost any byte except:

```text
NUL
/
```

inside a path component.

Therefore filenames may legally contain characters used by the snapshot format, including:

```text
|
newline
backslash
```

Before the snapshot format is considered stable, it must define how such paths are encoded.

Possible strategies include:

### Escaping

For example:

```text
\  -> \\
|  -> \|
newline -> \n
```

### Length-prefixed fields

Store the pathname length explicitly before its contents.

The chosen encoding must allow the parser to reconstruct the original pathname without ambiguity.

---

# 17. Snapshot Comparison

## 17.1 `diff`

Future command:

```text
fsnap diff <old-snapshot> <new-snapshot>
```

Compares two snapshots and reports changes.

Possible result categories:

```text
A = added
D = deleted
M = metadata or contents changed
P = permissions changed
L = symbolic link changed
```

The first implementation may load all snapshot records into memory and sort them by pathname.

---

# 18. Filesystem Verification

## 18.1 `verify`

Future command:

```text
fsnap verify <snapshot> <directory>
```

Compares a stored snapshot with the current filesystem.

It should eventually distinguish conditions such as:

```text
missing file
new file
type changed
size changed
permissions changed
owner changed
mtime changed
symbolic-link target changed
access error
```

Errors such as:

```text
ENOENT
EACCES
ENOTDIR
ELOOP
```

must not all be interpreted as equivalent conditions.

---

# 19. Portability

The project should prefer POSIX interfaces and avoid unnecessary Linux-specific functionality.

Code should be tested on multiple Unix-like systems where practical.

Current target environments include at least:

```text
Linux
NetBSD
```

The implementation must not rely on `dirent.d_type` always being populated.

`DT_UNKNOWN` must be handled correctly.

---

# 20. Build Requirements

The project should be compilable using a standard Makefile.

Recommended compiler configuration:

```text
-std=c11
-Wall
-Wextra
-Wpedantic
-Wconversion
```

Headers should reside under:

```text
include/
```

and compiler include paths should be configured through:

```text
-Iinclude
```

Automatic header dependency generation with:

```text
-MMD
-MP
```

is recommended.

---

# 21. Suggested Project Structure

```text
fsnap/
├── Makefile
├── README.md
├── include/
│   └── fsnap.h
├── src/
│   ├── main.c
│   ├── walk.c
│   ├── scan.c
│   ├── create.c
│   ├── parser.c
│   ├── compare.c
│   └── utility.c
└── tests/
```

The exact module layout may evolve as responsibilities become clearer.

---

# 22. Testing

The filesystem walker and snapshot writer should be tested against trees containing:

```text
regular files
empty files
directories
nested directories
symbolic links
broken symbolic links
hard links
FIFOs
character or block devices where available
unusual filenames
permission errors
```

Example test environment:

```sh
mkdir -p test/subdir

printf 'hello\n' > test/file.txt

ln test/file.txt test/hardlink.txt

ln -s file.txt test/link.txt

ln -s missing.txt test/broken-link

mkfifo test/pipe
```

The walker must never recursively follow `link.txt`, even if a symbolic link points to a directory.

---

# 23. Development Stages

The project is divided into incremental stages.

## Stage 1 — Filesystem Walker

Implement:

```text
fsnap scan
```

Goals:

- directory traversal;
- `dirent`;
- `d_type`;
- `DT_UNKNOWN`;
- `lstat()`;
- callback-based walker.

**Status: implemented.**

## Stage 2 — Snapshot Writer

Implement:

```text
fsnap create
```

Goals:

- filesystem metadata;
- `struct stat`;
- standard I/O;
- serialization;
- temporary files;
- robust cleanup.

**Status: implemented.**

## Stage 3 — Snapshot Parser

Implement:

```text
fsnap list
```

Goals:

- `getline()`;
- parsing;
- numeric conversion;
- input validation;
- dynamic memory;
- snapshot entry representation.

**Status: next development stage.**

## Stage 4 — Snapshot Comparison

Implement:

```text
fsnap diff
```

Goals:

- collections of records;
- sorting;
- comparison;
- filesystem identity and metadata semantics.

## Stage 5 — Filesystem Verification

Implement:

```text
fsnap verify
```

Goals:

- compare persisted metadata against the live filesystem;
- classify changes;
- handle filesystem errors correctly.

---

# 24. Optional Extensions

Once the basic project is complete, possible extensions include:

### Content hashing

Calculate checksums or hashes for regular files.

This introduces additional practice with:

```text
open()
read()
close()
```

and contrasts raw file I/O with standard I/O.

### Sparse-file detection

Compare logical file size with allocated blocks using fields such as:

```text
st_size
st_blocks
```

### Hard-link detection

Track:

```text
st_dev
st_ino
```

to identify multiple paths referring to the same inode.

### Snapshot format versioning

Add a header such as:

```text
FSNAP|1
```

to allow the on-disk format to evolve without making older snapshots impossible to recognize.

### Atomic snapshot replacement

Write the completed snapshot to a temporary file and atomically replace the destination where the target filesystem permits it.

### Process-based hashing

After studying Unix process management, file hashing may be distributed across worker processes.

### Signal handling

After studying Unix signals, long-running snapshot creation could respond cleanly to interruption and remove incomplete temporary files.

---

# 25. Learning Objectives

By the end of the project, the implementation should demonstrate practical understanding of concepts covered by the early chapters of *Advanced Programming in the UNIX Environment*, particularly:

- Unix filesystem semantics;
- file descriptors;
- file metadata;
- directories;
- inode-related concepts;
- symbolic links;
- standard I/O;
- buffering;
- error handling;
- POSIX types;
- portability;
- resource ownership.

The project should favor correctness, explicit error handling, and understanding of Unix behavior over minimizing the amount of code.
:::
