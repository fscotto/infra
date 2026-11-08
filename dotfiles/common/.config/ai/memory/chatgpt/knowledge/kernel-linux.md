# Sviluppo kernel Linux

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Percorso di studio (libri, roadmap, obiettivi)

- Obiettivo: apprendimento personale; estendere la programmazione di sistema in C (base: *Linux System Programming*) allo sviluppo di moduli kernel — cambio di paradigma (niente libc, "dentro" il kernel).
- *Linux Kernel Development* di Robert Love (lettura alternata): chiaro e ben organizzato, valido per basi concettuali e come ponte, ma datato — 3ª ed. del 2010 basata su kernel 2.6.x (oggi 6.x); API cambiate/deprecate; non copre KBuild moderno, eBPF, cgroup v2, ARM64, Rust.
- Testo successivo consigliato: *Linux Kernel Programming* di Kaiwan N. Billimoria (2ª ed. 2022, kernel 5.x; capp. 2–5: moduli, debug, logging, simboli). Per il modello driver: *Linux Device Drivers* (Rubini & Corbet, 3ª ed., datata ma valida). Riferimenti moderni: docs.kernel.org e sorgenti kernel.
- Percorso pratico moduli (esercizi progressivi): 1) Hello Kernel (`module_init`/`module_exit`, `pr_info`/`pr_alert`, `insmod`/`rmmod`, `dmesg`); 2) parametri (`module_param` int/charp); 3) procfs/sysfs (`proc_create`, `seq_file`, extra `kobject` + `sysfs_create_file`); 4) memoria (`kmalloc`/`kfree`, `GFP_KERNEL`); 5) sincronizzazione (spinlock, mutex, workqueue); poi `ftrace`, `kprobes`, `perf`, `EXPORT_SYMBOL`.

## Setup di sviluppo (VM, build, debug)

- Distro di riferimento: Arch Linux; pacchetti `emacs ripgrep ctags cscope gdb clang bear` (opz. `gcc`, `make`, `qemu` per build e test).
- Build kernel: clone `torvalds/linux` da git.kernel.org → `make defconfig` (o menuconfig/nconfig) → `make -j$(nproc)` → `make modules` + `modules_install` + `install`; test in VM QEMU con initramfs minimale. Config usata nei test: `make allyesconfig`.
- Benchmark reale su Geekom: build kernel mainline con allyesconfig ≈ 50 minuti, meno di 2 GB di RAM → i numeri "pesanti" riportati da Deepseek contestati come infondati.
- Build machine remota: serve a non bloccare la workstation (build molto costosa) e a testare su hardware reale (la VM non basta sempre).
- Editor: Vim/Neovim standard de facto tra i kernel hacker, Emacs alternativa storica molto usata, VS Code marginale; preferire editor leggeri a IDE pesanti (es. CLion) è la norma (i kernel hacker fanno comunque refactoring, col supporto del tooling).
- Navigazione codice (strategia ibrida): `ctags`/`cscope` (kernel fornisce `scripts/tags.sh`; indici: `make tags`, `cscope -Rbq`) per navigazione rapida; LSP `clangd` via `compile_commands.json` (generato con `bear make`) per analisi profonda e refactoring.
- Emacs: Eglot (nativo da Emacs 29) con clangd; `xcscope` (`C-c s s`, `C-c s g`, `C-c s c`) ed etags (`M-.`, `M-*`); build mirate con `M-x compile` (es. `make drivers/net/ethernet/intel/e1000e/`); debug con `M-x gdb` (`gdb -i=mi vmlinux`, `target remote :1234`) su QEMU avviato con `-s -S`; opzionale `realgud`.
- Accesso remoto: TRAMP lento su alta latenza → alternative: `ssh` + `tmux` + `emacs -nw`, oppure `emacs --daemon` + `emacsclient` sul server; X11 forwarding evitato; TRAMP (anche ottimizzato) solo su connessioni a bassa latenza/LAN.
- Debug/tracing: gdb + kgdb; `perf`, `ftrace`, `bpftrace`.
- Moduli: mai test sul sistema principale → VM (VirtualBox + Debian/Ubuntu, Docker privilegiato o QEMU; kernel ≥ 5.x, `linux-headers-$(uname -r)`); Makefile `obj-m` con `make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules`.

## Decisioni e preferenze stabili

- Editor per lo sviluppo kernel: **Emacs**. Evoluzione lug–set 2025: prima orientato su Neovim (aveva una buona config da far controllare), poi ha cambiato idea.
- Client email: **Neomutt** al posto di mu4e/Emacs mail (il fetch delle email si blocca spesso; vuole una TUI integrata che gestisca fetch/send/auth senza più pezzi). Migrazione ad aerc solo se i problemi persistono (aerc gestisce l'autenticazione direttamente).
- Ripartizione del workflow: Emacs = cockpit dello sviluppo (coding agent, gestione progetti, scrittura codice); email esterne con Neomutt (test); web Firefox; PDF Xournal++. Coding agent già integrati aprendoli nella dir del progetto da shell esterna.
- Workflow upstream: `git format-patch` e `git send-email` lanciati da magit; dentro Emacs resta configurato solo il client SMTP, per l'invio si può sfruttare la gestione mail integrata di Emacs.
- Stack desktop target: **Arch + GNOME** con unica estensione rilevante PaperWM (tiling); workflow terminal-first; abbandonato il "periodo Hyprland totale"; principio: "pochi strumenti chiari con responsabilità precise" invece di "un solo tool che fa tutto"; il WM non è il vero moltiplicatore di produttività.
- Distro: Arch come compromesso tra controllo UNIX-style e pragmatismo moderno (systemd accettato — richiesto da GNOME/Wayland); Void apprezzata (runit, minimalismo, BSD-like) ma incompatibile con GNOME.
- tmux: poco o per niente usato.

## Thread aperti

- Config Emacs per kernel-dev da esaminare/ottimizzare (mai avvenuto); ChatGPT aveva offerto script per rigenerare `tags`/`cscope.out`/`compile_commands.json`, snippet e integrazioni gdb/QEMU/Makefile.
- Esito del test Neomutt: eventuale passaggio futuro ad aerc.
- Migrazione effettiva ad Arch + GNOME + PaperWM discussa ma non confermata.
- Workflow su build machine remota da adattare al basso uso di tmux (emacs --daemon + emacsclient vs TRAMP).
- Contenuti troncati nei digest: risposta su "come attivare queste config" dopo `make allyesconfig` e tappa 6 del percorso moduli.

## Fonti
| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-07-03 | Linux Kernel Development | [transcripts/2025-07-03-linux-kernel-development.md](transcripts/2025-07-03-linux-kernel-development.md) |
| 2025-07-08 | Setup sviluppo kernel Linux | [transcripts/2025-07-08-setup-sviluppo-kernel-linux.md](transcripts/2025-07-08-setup-sviluppo-kernel-linux.md) |
| 2026-05-09 | Sviluppo Kernel Linux | [transcripts/2026-05-09-sviluppo-kernel-linux.md](transcripts/2026-05-09-sviluppo-kernel-linux.md) |

