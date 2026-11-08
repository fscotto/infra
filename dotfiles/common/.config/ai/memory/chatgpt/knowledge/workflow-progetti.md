# Workflow di sviluppo e progetti

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Workflow UNIX e strumenti scelti

- Principi: filosofia UNIX ("do one thing well"), tool CLI testuali e componibili, documentazione tecnica in plain text; compatibilità con i formati proprietari aziendali tramite strumenti di conversione.
- Struttura standard dei progetti: `~/projects/<nome>/` con `src/`, `bin/`, `doc/`, `test/` e `Makefile`; documenti sincronizzati nel cloud via `rclone` (prima Mega, poi pCloud).
- Toolchain per linguaggio: C (`gcc`/`clang`, `clang-format`, `cppcheck`, `make`, `gdb`, `valgrind`), Bash (`shellcheck`, `shfmt`, `bats`), Python (`black`, `ruff`, `mypy`, `pytest`, `venv`), Go (`go fmt`, `golangci-lint`, `gopls`, `go test`); formatter configurati anche per Lua e Zig.
- Editor — evoluzione: Neovim → **Emacs**, dichiarato "editor di riferimento per lo sviluppo" su Linux e centro operativo del workflow; su **FreeBSD** invece usa **vim** anche per lo sviluppo: Emacs non viene installato perché lì privilegia i tool nativi e storici UNIX.
- Emacs come hub, non come sostituzione ("integra, non inglobare"): org-mode (note, to-do, journaling), projectile, dirvish/dired, magit, LSP + dap-mode, vterm, tramp, pdf-tools per annotazioni PDF.
- Regola anti "Emacs come OS": non duplicare ciò che il sistema fa già bene (mail, fs, job control); se Emacs si rompe, il sistema deve continuare a funzionare.
- Desktop — evoluzione: fase Wayland valutata (alias pbcopy/pbpaste con `wl-clipboard` come funzioni, clipman su Sway, screenshot `grim` + notifica `fyi`) → ritorno a **X11 + i3**; distro **Linux Mint**; storage **pCloud** al posto di Mega.
- Preview file per formato: `bat` per i markdown; viewer PDF nel terminale; i file binari solo con output di `file`, mai nel pager; paging come flag esplicito, non default.
- PDF e immagini: `zathura` come viewer leggero/scriptabile (potenziato con indice/sidebar), `feh`/`sxiv` per le immagini; calibre valutato per le collezioni di PDF ma trovato poco coerente con la filosofia UNIX (valutato anche calibre-tui) → scartato.
- Mergetool grafico: **Meld**, integrato con l'editor via Telescope: confronto tra file, inclusa la versione del file corrente su un altro branch (primo branch = corrente, secondo selezionato, ricerca ricorsiva dalla root del progetto).
- Git: `.gitconfig` dichiarata produttiva e mantenuta contro ogni proposta di modifica — `delta` (tema catppuccin-mocha) come pager/differ, `meld` come difftool/mergetool, conflictstyle diff3, `pull.rebase`, firma GPG, alias (`co`, `br`, `ci`, `st`, `lg`, `undo`, `stash-all`…).
- Mail: **neomutt** scelto su mutt (patch integrate, notmuch, sidebar, truecolor, account multipli) e preferito a Thunderbird in un workflow UNIX; esplorate catene di programmi esterni (contatti), integrazione Google con più rubriche, PEC (in uso Namirial Spidmail), ProtonMail bridge, condivisione di mailbox locale con Thunderbird.
- Password di posta = preoccupazione principale: valutati unix pass e solo-Bitwarden; approdo a **GNOME Keyring + libsecret** (`secret-tool lookup` per `imap_pass` in neomutt, sblocco via PAM, config completa preparata per Arch + Hyprland); script per casella Gmail con log e commenti in inglese.
- ChatGPT come assistente di scrittura: riscrittura di email di servizio in forma più formale.
## Piano e metodo per i goal

- Goal dichiarato (workstation FreeBSD): sistema coerente con la filosofia UNIX, minimale ma realmente usabile ("minimale ma non ascetico"), tecnicamente difendibile, comprensibile end-to-end.
- Metodo di revisione: parte dall'elenco dei pacchetti installati manualmente, li motiva uno per uno e poi li riduce; ogni tool deve avere una ragione tecnica; domanda guida: "posso eliminarlo senza perdere una funzionalità essenziale?"; due tool per lo stesso lavoro → tenere il più semplice, evitare stack di daemon/wrapper.
- Dopo la revisione su FreeBSD rimossi: bat, fastfetch, hack-font, nerd-fonts, starship, zoxide (motivato e poi eliminato), lynis; confermati invece fzf, git-delta (differ predefinito per la review del codice), stow (dotfiles in repo git).
- Compromessi dichiarati: browser e multimedia non-UNIX confinati in `$HOME`, non integrati nel workflow, documentati come compromessi.
- Le regole si mettono per iscritto in documenti verificabili e vincolanti: `separazione_core_system_vs_user_environment.md`; regola angolare: il sistema deve restare funzionale anche in assenza completa di `$HOME`.
- Carica i file di configurazione (vim, git, bash) e i documenti di regole nella knowledge del progetto ChatGPT; chiede resoconti "stato dell'arte e cosa manca" come punti di controllo, considerando le altre chat del progetto parte integrante del riassunto.
- Il goal, una volta stabilito, "non è più in discussione" e viene tradotto in regole verificabili; i resoconti valutano, non riaprono le decisioni.
- Suckless = disciplina, non moda: patch solo per problemi reali, diff spiegabile riga per riga; FreeBSD va usato, non combattuto (rc(8), jail, pf; UFS+snapshot salvo necessità provata di ZFS).
- Scrivere C reale (filtri stdin→stdout, demoni semplici, tool di ispezione) per costruire il sistema, non solo configurarlo; documentare come se si dovesse rifare tutto da zero.

## Progetti in corso (stato e contesto)

- Progetti/tematiche sviluppate con ChatGPT (iniziative strutturate trattate come progetti):
  - Setup multi-macchina: `deadalus` workstation di lavoro, `ikaros` desktop personale (Void + i3/XFCE), `nymph` laptop T480, `prometheus` server Raspberry Pi.
  - Installazione automatizzata Void Linux: EFI + `/boot` + LUKS2 + LVM, split root/home, utente + runit + NetworkManager; poi conversione in Ansible (idempotenza, gestione pacchetti, deploy dotfiles tipo Rofi).
  - Automazione Fedora/AlmaLinux con Kickstart (problemi Flatpak, confronto con Ubuntu Autoinstall); script installazione Debian (btrfs + encryption).
  - Dotfiles & desktop: i3 "XFCE-lite" (tray, PipeWire, keyring via PAM, xdg-desktop-portal); tema grafico completo (Yaru dark, Rofi, Dunst, Alacritty deep black, i3bar/i3blocks).
  - Contesto building dei sistemi operativi (AGENTS.md tematico), integrando il playbook fatto con Codex.
- `infra` (github.com/fscotto/infra): playbook sviluppato con Codex, con proprio `AGENTS.md`; per il contesto va letto l'AGENTS.md più che il README.
- Contesto per agenti AI, evoluzione: prima `AGENTS.md` per ogni progetto nato su ChatGPT; poi, essendo l'agente locale **opencode** (non Codex), ristrutturato per lui: file markdown in `~/.config/opencode`, letti automaticamente come memoria dell'agente; distribuiti via `opencode_full_context.zip`.
- Struttura del contesto: `bootstrap.md` (sempre caricato) + `knowledge/` (os_setup, infra, architecture, desktop, dotfiles, cli, emacs, system_programming, kernel, server, philosophy) + `rules/` (safety, ansible, dotfiles, workflow) + `patterns/` (ansible_role, dotfiles_layering, service_setup, project_structure).
- Semantica: `knowledge/` = cosa è vero nel sistema; `rules/` = cosa l'agente non deve rompere; `patterns/` = come si fanno le cose; uso: sempre `bootstrap.md` + `rules/safety.md`, poi i file per task (es. infra → `knowledge/infra.md` + `rules/ansible.md`); un file riassuntivo per ogni argomento, coerente con le ultime scelte fatte.
- `rules/safety.md` (salvaguardia infra): mai rompere un host esistente; identificare host e layer (common/OS/profile/host); idempotenza, no duplicazioni, modifiche minime; vietata logica host-specifica in role condivise, pacchetti senza giustificazione, shell dove esiste un modulo Ansible; aree a rischio: display manager, PAM, networking, GPU/driver, boot; validazione: dry-run `--check --diff` e `--limit` su un singolo host prima di estendere.
- Salto concettuale dichiarato: da "documentazione" a **contesto persistente strutturato per agenti** ("sistema operativo per agenti"), un framework operativo personale.
- Stato del progetto FreeBSD (checkpoint finale): obiettivo chiaro e stabile; separazione core/user environment **chiusa e formalizzata**; core system completo e corretto (Xorg come infrastruttura, dwm/dmenu/st compilati manualmente, drm-kmod, nessuna configurazione personale in `/etc`, nessun tool di workflow nel core); user environment maturo (bash, vim, tmux, git con delta+meld come compromessi dichiarati, stow, lf, feh, sfeed, isync; compromessi confinati); workflow/git/shell/editor stabili, nessuna deriva "comfort-first".

## Memoria delle conversazioni (conclusioni sull'export ChatGPT)

- Export ufficiale OpenAI: Impostazioni → Controlli dati → Esporta dati → ZIP spedito via email/SMS; può richiedere fino a 7 giorni, link valido 24 ore.
- Contenuto: cronologia delle conversazioni in `conversations.json` (o più JSON numerati) più eventuali file/risorse associati.
- Limiti: è un backup dell'account, non un export/import strutturato dei Progetti; reimportare `conversations.json` non ricrea chat e sidebar; memorie, GPT e impostazioni non vengono trasferiti.
- Conclusione adottata: trasformare l'export in un archivio **Markdown/Org per progetto** (es. `chatgpt-archive/projects/fsnap/*.org`), versionato sotto Git e ricercabile con grep/ripgrep, invece di dipendere dall'interfaccia di ChatGPT — coerente con il workflow Emacs/Org.
- Esito: da questa conclusione nasce il sistema di memoria attuale — transcript completi + knowledge distillata in `~/.config/ai/memory/chatgpt/` tramite `scripts/chatgpt_export_to_memory.py` + distillazione AI — che rende il contesto delle conversazioni disponibile ai coding agent.

## Thread aperti

- FreeBSD: toolchain di sistema da dichiarare (`clang`, `make`, `lldb`) e uso esplicito degli strumenti BSD (`ktrace`, `truss`, `dtrace`); mancano 2-3 piccoli programmi C per studiare/interagire/misurare il sistema.
- FreeBSD: policy su servizi e runtime non ancora scritta ("chiusura concettuale" mancante, anche solo mentale).
- opencode: estensioni proposte e non ancora realizzate — `rules/infra_strict.md`, `patterns/validation.md` (checklist di test sempre), `knowledge/decisions.md` (registro delle motivazioni delle scelte, "oro puro nel tempo").
- Mail: `.muttrc` pronto per Gmail con GNOME Keyring offerto ma non ancora generato.
- Dopo il ritorno su Emacs/X11/Mint: tre prossimi passi rimasti in sospeso (Emacs "core" minimale; Org-mode come knowledge base tecnica + sync pCloud; audit di cosa tenere/buttare/sostituire rispetto al setup precedente).

## Fonti
| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-07-19 → 2026-05-16 | Workflow sviluppo UNIX | [2025-07-19-workflow-sviluppo-unix.md](transcripts/2025-07-19-workflow-sviluppo-unix.md) |
| 2025-08-05 → 2025-08-13 | Vantaggi di NeoMutt | [2025-08-05-vantaggi-di-neomutt.md](transcripts/2025-08-05-vantaggi-di-neomutt.md) |
| 2025-09-18 | Rendere email più formale | [2025-09-18-rendere-email-piu-formale.md](transcripts/2025-09-18-rendere-email-piu-formale.md) |
| 2026-01-27 → 2026-02-03 | Suggerimenti per un goal | [2026-01-27-suggerimenti-per-un-goal.md](transcripts/2026-01-27-suggerimenti-per-un-goal.md) |
| 2026-03-31 → 2026-04-03 | Progetti sviluppati insieme | [2026-03-31-progetti-sviluppati-insieme.md](transcripts/2026-03-31-progetti-sviluppati-insieme.md) |
| 2026-09-01 | Esportare Progetti E Chat | [2026-09-01-esportare-progetti-e-chat.md](transcripts/2026-09-01-esportare-progetti-e-chat.md) |

