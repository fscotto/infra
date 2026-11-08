---
conversation_id: "6866c486-7300-800c-be99-ac3501bf5b77"
title: "Linux Kernel Development"
created: 2025-07-03
updated: 2026-05-16
model: "auto"
messages: 8
---

# Linux Kernel Development

## Utente — 2025-07-03 19:57

Il libro Linux Kernel Development di Robert Love quanto è utile per imparare lo sviluppo kernel?

## ChatGPT — 2025-07-03 19:57

Il libro **"Linux Kernel Development" di Robert Love** è **stato uno dei testi di riferimento per imparare lo sviluppo del kernel Linux**, ma con alcune **importanti precisazioni**:

---

### ✅ **Punti di forza del libro:**
1. **Chiarezza espositiva**: Robert Love ha uno stile molto chiaro e accessibile, anche per chi non ha mai toccato codice kernel.
2. **Struttura ben organizzata**: il libro introduce gradualmente i concetti fondamentali dello sviluppo kernel (gestione dei processi, scheduling, interrupt, sincronizzazione, memoria, file system, ecc.).
3. **Buona introduzione pratica**: spiega come compilare il kernel, aggiungere moduli e interagire con il sistema.

---

### ⚠️ **Limiti (soprattutto nel 2025):**
1. **Non è aggiornato**: l'ultima edizione (terza, 2010) è basata su un kernel **2.6.x**, mentre oggi siamo al kernel **6.x**.
   - Molte API sono cambiate o deprecate.
   - Le architetture multiprocessore, il model threading, i meccanismi di sicurezza e le interfacce sono molto più complessi ora.
2. **Non tratta le novità recenti**: come il sistema di build `KBuild`, eBPF, cgroup v2, nuove architetture ARM64, Rust nel kernel, ecc.

---

### 🎯 **Quando è ancora utile nel 2025?**
- Se **sei alle prime armi** con lo sviluppo kernel e vuoi **capire le basi**: è un'ottima introduzione.
- Se ti interessa una **visione concettuale** del funzionamento del kernel, anche se con esempi datati.
- Se vuoi un **ponte tra la programmazione di sistema in C e lo sviluppo kernel**.

---

### 🔁 Cosa leggere dopo / al posto di Robert Love:
1. **"Linux Kernel Programming" di Kaiwan N Billimoria** (seconda edizione, 2022) – molto più aggiornato, tratta il kernel 5.x.
2. **"Linux Device Drivers" (terza edizione)** di Rubini & Corbet – anch'esso un po’ datato (2.6), ma ottimo per comprendere il modello driver.
3. **La documentazione ufficiale del kernel** (`https://docs.kernel.org`) – fondamentale per lavorare con versioni moderne.
4. **Sorgenti del kernel** (github.com/torvalds/linux): leggere e sperimentare direttamente è insostituibile.

---

### ✅ Conclusione:
**"Linux Kernel Development" è ancora utile come introduzione teorica e pratica**, ma **va integrato con materiale aggiornato**. Pensalo come **un primo gradino** in un percorso più lungo e tecnico. Se già hai basi solide in C e programmazione di sistema, potresti trarne meno beneficio rispetto a chi parte da zero.

Se vuoi, posso aiutarti a costruire un piano di studio più moderno e progressivo per imparare lo sviluppo kernel partendo da dove sei ora.

## Utente — 2025-07-03 19:59

Quale è il libro considerato migliore per lo sviluppo kernel?

## ChatGPT — 2025-07-03 19:59

Nel 2025 **non esiste un singolo libro “migliore” universalmente riconosciuto** per lo sviluppo del kernel Linux, perché:

- lo **sviluppo del kernel è un campo molto vasto** (scheduler, memory management, networking, device drivers, sicurezza, architettura hardware…);
- la **documentazione ufficiale e i sorgenti stessi** del kernel sono spesso la fonte primaria per i professionisti.

Tuttavia, ecco i **libri più autorevoli e consigliati** oggi, con una breve descrizione dei punti di forza:

---

### 🔵 **1. _Linux Kernel Programming_ – Kaiwan N Billimoria (Seconda edizione, 2022)**  
**✅ Il più moderno e pratico tra i libri generici.**

- Basato su kernel 5.x (più vicino ai 6.x attuali).
- Copre lo sviluppo di moduli, gestione memoria, processi, interrupt, ecc.
- Include esempi e mini-progetti hands-on.
- Spiega il sistema di build (`KBuild`) e il debugging con `ftrace`, `gdb`, ecc.

**Ideale per:** chi vuole iniziare seriamente con una base aggiornata e pratica.

📘 **Valutazione**: ⭐⭐⭐⭐½

---

### 🔵 **2. _Understanding the Linux Kernel_ – Bovet & Cesati (terza edizione, 2005)**  
**✅ Ottimo per la teoria approfondita.**

- Analizza in dettaglio il funzionamento interno del kernel.
- Basato su kernel 2.6, ma con molte sezioni ancora valide sul piano teorico (scheduler, memoria virtuale, VFS, ecc.).
- Non è pensato per scrivere codice kernel, ma per **capirne la logica interna**.

**Ideale per:** chi vuole capire come funziona il kernel "sotto il cofano", più che scrivere moduli.

📘 **Valutazione**: ⭐⭐⭐⭐

---

### 🔵 **3. _Linux Device Drivers_ – Rubini, Corbet, et al. (terza edizione, 2005)**  
**✅ Il riferimento storico per scrivere driver.**

- Incentrato sui device driver, modulo fondamentale dello sviluppo kernel.
- Basato su kernel 2.6 – molti concetti sono ancora validi, ma richiede confronto con la documentazione attuale.
- Il codice va adattato alle moderne API.

**Ideale per:** chi vuole scrivere driver e interfacciarsi con l’hardware.

📘 **Valutazione**: ⭐⭐⭐½ (perché datato)

---

### 🔵 **4. _Linux Kernel Development_ – Robert Love (2010)**  
**✅ Introduttivo e ben scritto, ma obsoleto.**

- Ottimo come primo libro, ma non sufficiente da solo per sviluppare sul kernel moderno.

📘 **Valutazione**: ⭐⭐⭐ (buono come inizio)

---

### 🟢 **Fonti alternative imprescindibili:**

- 🧾 **[docs.kernel.org](https://docs.kernel.org/)** – documentazione ufficiale (aggiornata e curata).
- 🧑‍💻 **Il codice sorgente del kernel** (https://github.com/torvalds/linux).
- 🧵 **Mailing list LKML, commit log e patchset** – essenziali per seguire l'evoluzione del kernel.
- 🎥 Corsi (es. Linux Foundation: *Developing Linux Device Drivers*, *Linux Kernel Internals*).

---

### ✅ **Conclusione**
> Se dovessimo sceglierne **uno solo oggi nel 2025**, il **migliore punto di partenza pratico è _Linux Kernel Programming_ di Kaiwan N Billimoria** (seconda edizione).

Poi, per una comprensione più profonda o mirata:
- _Understanding the Linux Kernel_ per la teoria.
- _Linux Device Drivers_ + docs.kernel.org per chi vuole scrivere driver.

Se vuoi, posso aiutarti a strutturare un percorso combinando questi testi con esempi pratici. Vuoi qualcosa di progressivo per lo studio?

## Utente — 2025-07-03 20:05

Se volessi partire con lo sviluppo di moduli kernel dopo aver letto Linux System Programming

## ChatGPT — 2025-07-03 20:05

Ottimo! Se hai già letto (o stai leggendo) **_Linux System Programming_**, hai un’ottima base di:

- programmazione in C a basso livello,
- interazione con syscalls e il sistema operativo,
- concetti come file descriptor, memoria, segnali, thread e processi.

Da qui, passare allo **sviluppo di moduli del kernel Linux** è **un passo naturale**, ma richiede un cambio di paradigma: **non c'è più libc, non c'è `printf`, sei “dentro” il kernel**.

---

## 🚀 **Percorso consigliato per iniziare con i moduli kernel**

### 🧱 **Prerequisiti**
Assicurati di avere:
- Buona padronanza del C (strutture, puntatori, macro, pre-processore).
- Una distribuzione Linux con:
  - un kernel compatibile (idealmente 5.x o 6.x),
  - headers del kernel installati (`linux-headers-$(uname -r)`),
  - strumenti come `make`, `gcc`, `insmod`, `rmmod`, `dmesg`.

> 👉 Evita di fare test sul tuo sistema principale: lavora in una **VM** (es. con VirtualBox + Debian/Ubuntu) o in un **ambiente Docker con privilegi**, oppure con **QEMU** se vuoi fare emulazione avanzata.

---

## 📘 **Fase 1: Leggere / consultare un libro moderno**

🔹 **Consigliato**:  
📗 _Linux Kernel Programming_ – Kaiwan N. Billimoria (2022)  
- Capitoli 2–5: introduzione, moduli, debug, logging, kernel symbols.  
- Ottimo equilibrio tra teoria e codice.

---

## ✍️ **Fase 2: Scrivere il primo modulo**

Un modulo semplice:

```c
#include <linux/init.h>
#include <linux/module.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Tuonome");
MODULE_DESCRIPTION("Un semplice modulo kernel di esempio");

static int __init my_module_init(void) {
    pr_info("Ciao dal modulo kernel!\n");
    return 0;
}

static void __exit my_module_exit(void) {
    pr_info("Addio dal modulo kernel!\n");
}

module_init(my_module_init);
module_exit(my_module_exit);
```

Makefile:

```make
obj-m += mymodule.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
```

Comandi:

```bash
make
sudo insmod mymodule.ko
dmesg | tail
sudo rmmod mymodule
```

---

## 🧪 **Fase 3: Approfondimenti**

🔧 Impara a:
- Leggere e usare `dmesg`, `ftrace`, `kprobes`, `perf`.
- Scrivere moduli con parametri (`module_param()`).
- Esportare simboli (`EXPORT_SYMBOL()`).
- Interagire con il file system (`procfs`, `sysfs`).
- Gestire sincronizzazione (`spinlock`, `mutex`, `semaphore`).

---

## 📚 **Risorse consigliate**

| Obiettivo | Risorsa |
|----------|---------|
| Capire le basi del kernel moderno | _Linux Kernel Programming_ (Billimoria) |
| Guida aggiornata e ufficiale | [docs.kernel.org](https://docs.kernel.org/) |
| Esempi pratici moderni | [The Linux Kernel Module Programming Guide (modern fork)](https://sysprog21.github.io/lkmpg/) |
| Imparare dai sorgenti | [torvalds/linux on GitHub](https://github.com/torvalds/linux) |

---

## 🧭 **Suggerimento di percorso pratico**
1. Scrivi 2–3 moduli “hello world” con vari parametri.
2. Esponi dati via `/proc` o `/sys`.
3. Crea un modulo che registra un handler IRQ fittizio.
4. Scrivi un modulo che alloca memoria e la gestisce.
5. Prova a interagire con moduli già caricati (dipendenze, simboli).

---

## ✅ Conclusione

Con **_Linux System Programming_** alle spalle, sei pronto a partire con lo sviluppo di moduli kernel. Inizia con piccoli esercizi, **lavora sempre in un ambiente sicuro (VM o emulazione)** e impara leggendo il codice sorgente del kernel.

Se vuoi ti posso preparare un **mini-percorso pratico in 4–6 tappe**, con esercizi progressivi. Ti interessa?

## Utente — 2025-07-03 20:09

Sì grazie

## ChatGPT — 2025-07-03 20:09

Perfetto! Ecco un **mini-percorso pratico in 6 tappe** per iniziare a scrivere **moduli kernel Linux**, pensato come naturale prosecuzione a ciò che hai imparato in *Linux System Programming*. Ogni tappa introduce concetti fondamentali, con esercizi reali da implementare.

---

## 🧭 **Percorso pratico – Moduli Kernel Linux**

### 🔧 **Ambiente consigliato**
- **Linux (VM)** con kernel ≥ 5.x
- Installati:
  ```bash
  sudo apt install build-essential linux-headers-$(uname -r)
  ```
- Una directory di lavoro dedicata con un file `Makefile` come visto prima.

---

### ✅ **Tappa 1: Hello Kernel!**

**Obiettivo**: Scrivere il primo modulo, caricarlo, scaricarlo, esaminare `dmesg`.

🛠️ Cosa fare:
- Crea un modulo che stampa un messaggio all’inserimento (`insmod`) e all’eliminazione (`rmmod`).
- Usa `pr_info()` e `pr_alert()` per variare i livelli di log.
- Leggi l'output con `dmesg | tail`.

🎯 Concetti:
- `module_init`, `module_exit`, `MODULE_LICENSE`.
- Logging con `pr_*`.
- Comandi base: `insmod`, `rmmod`, `dmesg`.

---

### ✅ **Tappa 2: Parametri del modulo**

**Obiettivo**: Passare valori al modulo da `insmod`.

🛠️ Cosa fare:
- Aggiungi un parametro intero (`int`) e una stringa (`charp`) al modulo.
- Stampa il valore nei log quando il modulo viene caricato.

```c
module_param(myint, int, 0);
module_param(mystr, charp, 000);
```

🎯 Concetti:
- `module_param`, tipi e permessi.
- Interazione tra spazio utente e kernel in fase di caricamento.

---

### ✅ **Tappa 3: Procfs o Sysfs – Esponi dati al sistema**

**Obiettivo**: Fare in modo che il modulo **esponga dati leggibili dall’utente** via `/proc` o `/sys`.

🛠️ Cosa fare:
- Crea una voce in `/proc/my_module` che stampa un contatore o un messaggio.

🎯 Concetti:
- `proc_create()`, `proc_remove()`, `seq_file`.
- Comunicazione kernel ↔ userspace.

📌 Extra: prova anche con `sysfs` (`kobject_create_and_add` e `sysfs_create_file`).

---

### ✅ **Tappa 4: Gestione memoria kernel**

**Obiettivo**: Allocare e liberare memoria nel modulo.

🛠️ Cosa fare:
- Alloca un array dinamico con `kmalloc()`.
- Inizializzalo in `init`, liberalo in `exit`.

🎯 Concetti:
- `kmalloc`, `kfree`, `GFP_KERNEL`.
- Gestione sicura della memoria nel kernel.

📌 Extra: stampa l’indirizzo della memoria con `pr_info("%px", ptr);`.

---

### ✅ **Tappa 5: Sincronizzazione nel kernel**

**Obiettivo**: Usare un meccanismo di sincronizzazione semplice.

🛠️ Cosa fare:
- Crea un modulo che ha un contatore protetto da un `spinlock` o `mutex`.
- Fai accedere più volte (simulando) da thread kernel o workqueue.

🎯 Concetti:
- `DEFINE_SPINLOCK`, `spin_lock`, `spin_unlock`.
- `mutex_init`, `mutex_lock`, `mutex_unlock`.

📌 Extra: guarda anche `atomic_t` e `atomic_inc()` per contatori semplici.

---

### ✅ **Tappa 6: Creare un task kernel o workqueue**

**Obiettivo**: Fare qualcosa di asincrono nel modulo.

🛠️ Cosa fare:
- Usa `kthread_run()` per creare un thread nel kernel che stampa periodicamente un messaggio.
- In alternativa, usa una **workqueue** (`queue_work`) per simulare un task ritardato.

🎯 Concetti:
- Thread kernel (`kthread_create`, `kthread_run`, `kthread_stop`).
- `schedule_timeout`, `msleep`.

📌 Extra: aggiungi un parametro per fermare il thread dopo un certo numero di esecuzioni.

---

## 🧩 **Bonus: Idee per esercizi extra**
- Crea un modulo che tiene traccia del numero di chiamate a `open()` su un file usando `kprobes`.
- Crea un modulo che registra un handler di interrupt software (`request_irq()` con un IRQ fittizio o simulato).
- Scrivi un modulo che logga eventi quando un file viene creato o cancellato in una directory.

---

## 📚 Risorse rapide da consultare
- [https://docs.kernel.org/](https://docs.kernel.org/)
- [Linux Kernel Module Programming Guide (aggiornata)](https://sysprog21.github.io/lkmpg/)
- [Kaiwan’s GitHub – esempi kernel](https://github.com/kaiwan/linux-kernel-programming-examples)

---

Se vuoi, posso seguirti **tappa per tappa**: mi dici su quale vuoi iniziare e ti do un esercizio più dettagliato con codice ed estensioni!
