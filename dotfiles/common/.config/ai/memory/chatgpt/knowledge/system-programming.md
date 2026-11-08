# Programmazione di sistema — C, UNIX APIs, APUE

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Percorso di studio e obiettivi

- Partenza (giu 2025): programmatore Java professionista, conosce già la sintassi di C, vuole passare alla programmazione di sistema da zero.
- Piano di studio a fasi (riportato in più occasioni): linguaggi C, Bash, Python, Go, Zig; Fase 1 fondamenti (algoritmi/strutture dati, sistemi operativi con OSTEP/Silberschatz, git); Fase 2 reti, container e system programming (Modern C, Linux System Programming, APUE, CS:APP); Fase 3 kernel programming e principi di design; Fase 4 opzionale (UNIX Network Programming vol. 1, DDIA).
- Primo piano operativo: 12 settimane su Linux System Programming (R. Love, 2ª ed.): 4 giorni/sett. lettura + esercizi, 1 giorno/sett. progetto hands-on; diario di apprendimento (concetti chiave, codice scritto, errori e soluzioni); piani esportati anche in RTF compatibile con Apple Notes.
- Esercizi su LSP (repo `github.com/fscotto/system-programming`): mycp, tree, run_scripts, downloader multi-thread simulato, benchmark di allocazione (malloc/calloc/mmap), esercizio segnali SIGINT/SIGUSR1; per ciascuno Makefile (target build/run/test/valgrind/clean), unit test e report valgrind automatici (run_tests.sh).
- Dopo la fine di LSP: consolidamento reimplementando le coreutils GNU (cartella `exercises/coreutils/`: ls ed echo sviluppati, sleep spiegato); indice degli esercizi in `exercises/README.md`.
- Consigli adottati: consolidare il C con Modern C e la teoria dei SO prima/in parallelo ad APUE; le socket non sono trattate in LSP → networking demandato ad APUE (richiesto sommario del cap. 16); prima del networking, rinforzare file/processi/thread/segnali via coreutils (dubbio espresso sulla reale necessità del networking in questa fase).
- Modern C (Gustedt) scelto al posto di K&R (fermo a C89/C90); percorso: capp. 1–6, 7, 8, 10, 14 (poi 9, 11, 12, 13, 15); Modern C e alcuni libri della Fase 1 non ancora terminati.
- Dal 2026 APUE (Stevens & Rago) è il testo principale; a lug 2026 l'utente è al cap. 6 e consolida i capp. 1–5 con il progetto fsnap; orientamento dichiarato: sviluppo user-space (non kernel), più pratica su C e algoritmi mentre studia le API POSIX.
- xv6 (giu 2026): affiancare alla lettura di APUE un corso su xv6 per vedere il lato kernel (es. `fork()` in APUE → `sys_fork()` in xv6); consigliato il corso MIT 6.S081 (ex 6.828); xv6 rende concreta la teoria ma non la sostituisce; OSTEP solo selettivo (virtual memory, concurrency, scheduling, persistence); non trasformare xv6 in un progetto kernel completo; obiettivo: arrivare a leggere il kernel Linux con più sicurezza.
- Ambiente (giu 2026): Linux come piattaforma di sviluppo ("non cerco purezza UNIX, ma sviluppare con i tool che preferisco"); manpage NetBSD ritenute superiori come riferimento POSIX; lavoro su terminale con Vim, con vimrc "onefile" senza plugin; LSP: utile ma non centrale.
- Skill del system programmer (sintesi ChatGPT): C solido; API POSIX/UNIX la skill più importante (fd, open/read/write/close, fork/exec, waitpid, pipe, segnali, processi/thread, mmap, socket); interno del SO; debugging (gdb, strace, ltrace, perf, valgrind); toolchain; "chi padroneggia APUE può già definirsi system programmer junior".

## Progetto fsnap (stato, struttura, decisioni)

- Origine (lug 2026): consolidare i capp. 1–5 di APUE con un unico progetto "vero"; scartato l'ennesimo clone isolato di un comando Unix (mycp e tree già realizzati).
- Repo: `github.com/fscotto/fsnap`; layout `src/` + `include/`; Makefile con `-Iinclude` (fix dell'errore `undefined reference to scan` durante il link); review del codice richiesta più volte a ChatGPT.
- Concetto: utility POSIX in C che attraversa ricorsivamente un albero di directory, crea snapshot testuali dei metadati del filesystem, li legge e valida, confronta snapshot e verifica lo stato corrente.
- Comandi progettati:
```text
fsnap scan <directory>
fsnap create <directory> <snapshot>
fsnap list <snapshot>
fsnap diff <old.fsnap> <new.fsnap>
fsnap verify <snapshot> <directory>
```
- Formato snapshot: testuale, campi separati da `|`, scelto esplicitamente contro un formato binario (più facile da ispezionare, debuggare e leggere via stdio).
  - Record inizialmente proposto: path, tipo (F/D/L), device ID, inode, permessi, nlink, UID, GID, size, atime, mtime, ctime, target del symlink (es. `F|src/main.c|2049|83124|0644|1|1000|1000|4821|1722410134`).
  - Record della specifica finale: `type|permissions|uid|gid|size|mtime|path` (es. `F|0644|1000|1000|125|1753999812|src/main.c`).
- Requisiti di `scan`: opendir/readdir/closedir, lstat(), readlink(); niente nftw() inizialmente (nasconderebbe la parte da esercitare); ignorare `.` e `..`; non seguire i symlink, trattati come foglie comuni (se non si segue il link, nel walk non serve distinguerli dai file regolari); fallback a lstat() quando `dirent.d_type == DT_UNKNOWN`; chiara la differenza tra stat() e lstat(); walker generico `walk(directory, operation, context)` indipendente dall'operazione, riusato da scan e create; errori di traversal e callback propagati al chiamante.
- Portabilità: requisito esplicito (Linux e NetBSD); scan verificato funzionante anche su NetBSD, preludio al punto 2.
- `create` (punto 2): riusa il walker, raccoglie i metadati con lstat() e li serializza; durante lo sviluppo errori "bad descriptor" con mkstemp (ipotesi dell'utente: il file di mkstemp è opaco); dopo revisione del repo l'utente dichiara tutto risolto.
- `list` (punto 3): parser, percorso inverso di create; richieste solo le specifiche, non il codice; linee di lunghezza arbitraria (no buffer fissi tipo `char line[1024]`); separazione dei campi e conversioni numeriche controllate (valore valido, campo vuoto, caratteri residui, overflow, negativi non ammessi); validazione semantica (tipo `X|` sconosciuto, permessi `9999`, size negativa per file regolare); errori con numero di riga (`snapshot.fsnap:12: invalid uid`); decisioni aperte: pathname contenenti `|` o newline, chi possiede la memoria del pathname, quali controlli nel parser e quali nelle fasi successive.
- Specifica finale richiesta in inglese ("fsnap — Project Specification"): goals = traversal, metadati, file descriptor, stdio, link simbolici e hard link, tipi POSIX, error handling con errno, portabilità Unix, gestione risorse, parsing testuale, interfacce C riutilizzabili; non-goal iniziali (filesystem monitoring, real-time change detection, parallelismo, thread, garanzie crittografiche, compressione, network sync, feature FS-specifiche) come estensioni opzionali future.
- Stato a fine conversazione (ago 2026): scan completato (Linux + NetBSD); create completato; list/parser in fase di progettazione; diff e verify da implementare.

## Conoscenze e correzioni tecniche chiave apprese

- I/O su file (mycp): per l'usage usare `fprintf(stderr, "Usage: %s ...", argv[0])`, non perror; copiare con loop read/write fino a read()==0, senza pre-calcolare la dimensione del file; riprovare su EINTR; controllare anche gli errori di close; buffer da 4096 byte.
- Processi (run_scripts): figli con fork() + execlp("/bin/bash", "bash", script, NULL); attesa con waitpid(pid,&status,0) e non wait(); esito con WIFEXITED/WEXITSTATUS e WIFSIGNALED/WTERMSIG (distinguere uscita normale da terminazione via segnale); gestire errori di fork/exec/waitpid con perror e exit.
- Segnali: nell'handler solo funzioni async-signal-safe (write, _exit; non exit/perror); contatori come `volatile sig_atomic_t`, non una semplice `static int`; sa_mask va costruita con sigemptyset + sigaddset (non `sa_mask = SIGINT|SIGUSR1`); strlen non è garantita re-entrant nell'handler; wrapper safe_print(msg,len) con write(..., len-1): non stampava la riga intera.
- Benchmark memoria: tempi con clock_gettime(CLOCK_MONOTONIC); uso memoria via /proc/self/status o /proc/self/statm; firme diverse delle funzioni di allocazione → array di function pointer (typedef StatsFn) con wrapper; blocchi di prova da 1024 a 100000 byte; statistiche su tempi medi e picco RSS.
- echo: calcolare prima le lunghezze in un array, un solo malloc + memcpy e una sola write (no strcat/strlen ripetuti); la variante con cache delle strlen produceva segfault, corretta ricalcolando gli offset; byte extra per il newline (chiarito il +1).
- ls: chiarito il trattamento del path al raggiungimento di PATH_MAX.
- Makefile: `-Iinclude` per gli header in cartella dedicata; standard C11 impostato; target build/run/test/valgrind/clean; cleanup eseguito dal Makefile; report valgrind generati via run_tests.sh.
- Shell POSIX (script con auto-elevazione sudo): `exec sudo bash "$0" "$@"` reinvoca lo script con l'interprete corretto; `exec` sostituisce la shell nel processo corrente e chiude subito l'emulatore di terminale (osservato); `sudo env "$0"` esegue con la shell indicata dal shebang; lo script non era POSIX: `[[ ]]` → `[ ]`, `source` → `.`, `$BASH_SOURCE` → `$0`, niente pipefail; `yay` è una dipendenza specifica di Arch.
- LSP in C: un LSP accurato (clangd) richiede compile_commands.json; utile per navigazione/diagnostica ma non sostituisce make, man, grep, ctags, cscope, gdb, strace, valgrind; i bug tipici del system programming (syscall errate, errno incompleta, EINTR ignorato, fd leak, race/deadlock, buffer troppo piccoli, UB, differenze POSIX/Linux, linking/ABI) non emergono da un LSP.

## Preferenze di coding emerse

- Low-level POSIX prima delle astrazioni: API dirette (no nftw in fsnap), formato dati testuale e ispezionabile.
- Il codice lo scrive da solo: chiede specifiche, test, makefile e review del proprio codice ("è corretto secondo le specifiche?", "dai un altro sguardo al repo"); per il punto 3 di fsnap, esplicitamente "Non darmi il codice già fatto".
- Ogni esercizio dotato di unit test (anche con mock della struttura delle directory), integrazione valgrind e Makefile con target di build/test/clean.
- Inglese per README, specifiche di progetto e commenti del Makefile; indice markdown centralizzato degli esercizi su GitHub.
- Gestione errori sistematica: perror + errno, controllo del ritorno di ogni syscall, gestione di EINTR.
- Portabilità: requisito del progetto fsnap (Linux + NetBSD); NetBSD usato come secondo sistema di prova; manpage NetBSD come riferimento per le funzioni POSIX.
- Stile kernel per il C (tabstop/shiftwidth 8, colonna 80) con vimrc onefile senza plugin; quickfix al centro del flusso (`:make` → `:copen` → `:cnext`); grepprg rg con fallback a grep; giudizio sulla config: portabilità 8/10, C/POSIX 8/10, kernel style 8/10, minimalismo 9/10, robustezza VimL 6.5/10, LSP readiness 5/10.
- Codice pubblico su GitHub: `fscotto/system-programming` (esercizi), `fscotto/fsnap` (progetto APUE), gist per la .vimrc onefile.
- Piani di studio mantenuti come markdown esportabile (anche RTF per Apple Notes).

## Thread aperti

- fsnap: implementare `list`/parser con le decisioni ancora aperte (pathname con `|` o newline, memoria del pathname, confine parser/validazione); poi `diff` e `verify`; estensioni opzionali dai non-goal.
- APUE: proseguire dal cap. 6; socket/networking (cap. 16) in agenda, con dubbio già espresso sul momento giusto della fase reti.
- Modern C: capitoli selezionati (1–6, 7, 8, 10, 14) da leggere; alcuni libri della Fase 1 del piano non completati.
- xv6 (MIT 6.S081): da affiancare ad APUE per processi, memoria, filesystem e system call.
- Esercizio segnali: safe_print nell'handler non ancora funzionante (stampa solo parte della riga).
- Config vimrc: parti aggressive/fragili da sistemare; eventuale LSP da valutare.
- coreutils: proseguire con i comandi rimanenti del piano (svolti ls ed echo; sleep spiegato).

## Fonti
| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-06-17 | Programmazione di sistema | [transcripts/2025-06-17-programmazione-di-sistema.md](transcripts/2025-06-17-programmazione-di-sistema.md) |
| 2025-07-08 | Elevazione privilegi con script | [transcripts/2025-07-08-elevazione-privilegi-con-script.md](transcripts/2025-07-08-elevazione-privilegi-con-script.md) |
| 2026-06-02 | Studiare xv6 con APUE | [transcripts/2026-06-02-studiare-xv6-con-apue.md](transcripts/2026-06-02-studiare-xv6-con-apue.md) |
| 2026-06-21 | Skill system programmer | [transcripts/2026-06-21-skill-system-programmer.md](transcripts/2026-06-21-skill-system-programmer.md) |
| 2026-07-31 | Progetto fsnap per APUE | [transcripts/2026-07-31-progetto-fsnap-per-apue.md](transcripts/2026-07-31-progetto-fsnap-per-apue.md) |


