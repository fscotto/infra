---
conversation_id: "6a1f410f-f820-8390-8a34-b6c737026d88"
title: "Studiare xv6 con APUE"
created: 2026-06-02
updated: 2026-06-02
model: "gpt-5-5"
messages: 2
---

# Studiare xv6 con APUE

## Utente — 2026-06-02 22:46

Rispetto a quanto spiegato finora sui sistemi operativi ho trovato un corso che spiega nel dettaglio il sistema opearativo xv6.
Potrebbe essere utile seguire il corso per capire come funziona un sistema operativo, mentre leggo APUE, invece di leggere la teoria sui libri?

## ChatGPT — 2026-06-02 22:47

Sì, secondo me può essere molto utile, ma con una precisazione importante: **xv6 non sostituisce la teoria di un libro come OSTEP**, la rende concreta.

Considerando il tuo percorso attuale:

- Hai già completato gran parte della programmazione di sistema user-space.
- Stai leggendo APUE.
- Hai interesse reale per kernel e sistemi operativi.
- Preferisci imparare attraverso codice ed esercizi piuttosto che tramite teoria astratta.

Per il tuo profilo, studiare xv6 è probabilmente più efficace che leggere centinaia di pagine di teoria in sequenza.

Il vantaggio di xv6 è che puoi vedere concretamente:

- processi (`fork`, `exec`, `wait`)
- scheduler
- context switch
- virtual memory
- trap e interrupt
- system call
- file system
- locking e concorrenza

Tutte cose che in APUE usi dall'esterno.

Ad esempio:

Quando in APUE leggi:

```c
pid = fork();
```

con xv6 puoi andare a vedere:

```c
sys_fork()
```

e seguire l'intero percorso fino alla creazione del processo nel kernel.

Questo crea un collegamento mentale molto potente tra user space e kernel space.

---

Se dovessi scegliere oggi per il tuo percorso, farei:

### Priorità 1: APUE

Continua APUE come testo principale.

### Priorità 2: xv6

Quando incontri un argomento importante:

- processi
- memoria
- file system
- segnali (xv6 ne ha una versione semplificata)
- system call

guarda come è implementato in xv6.

### Priorità 3: OSTEP selettivo

Userei OSTEP come riferimento.

Non leggerei necessariamente tutto in ordine.

Aprirei i capitoli quando servono:

- Virtual Memory
- Concurrency
- Scheduling
- Persistence

---

Una combinazione che per te potrebbe funzionare molto bene è:

| APUE | xv6 |
|--------|--------|
| Impari l'interfaccia | Vedi l'implementazione |
| User Space | Kernel Space |
| Come usare `fork()` | Come funziona `fork()` |
| Come usare `open()` | Come funziona `open()` |
| Come usare `wait()` | Come funziona `wait()` |

---

C'è però una cosa che eviterei.

Non trasformare lo studio di xv6 in un progetto di sviluppo kernel completo.

Molti iniziano a:

- aggiungere syscall
- modificare scheduler
- implementare paging avanzato

e finiscono per passare mesi su xv6 senza consolidare APUE.

Nel tuo caso lo vedrei come:

> "Leggo APUE → apro xv6 → verifico come il kernel realizza ciò che APUE mi ha appena insegnato."

---

Se dovessi consigliarti un solo corso su xv6, quello del entity["organization","Massachusetts Institute of Technology","MIT xv6 Operating Systems course"] (6.S081, ex 6.828) è probabilmente il migliore materiale disponibile oggi per capire come funziona un sistema operativo attraverso il codice. Alternato ad APUE, è un'accoppiata estremamente forte per arrivare poi a leggere codice del kernel Linux con molta più sicurezza.
