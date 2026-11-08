# Editor — vim, neovim, emacs

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Posizioni e preferenze stabili

- Vim è l'editor primario per lo sviluppo; Emacs resta lo strumento di authoring: appunti in Org Mode (anche sulla workstation Windows di lavoro), documentazione, curriculum e altri documenti.
- Linguaggi dichiarati: C per lo sviluppo sui sistemi operativi, Go lato applicativo, Bash/Python per gli script di automazione; per lavoro Java su IntelliJ.
- Ergonomia comune: Vim-style sugli IDE — IdeaVim installato su IntelliJ; Vim Motion su VS Code/IntelliJ valutato per abituarsi rapidamente; evil-mode su Emacs scartata (torna a Emacs "puro": già usato per mesi senza evil).
- Criteri guida stabili: strumenti semplici, riproducibili, con ruoli ben distinti; FOSS ogniqualvolta possibile; nessuna scelta "per partito preso" — spirito Gilfoyle, "pratico più che ideologico" (la gente gli dice di essere "tipo Gilfoyle").
- Vim one-file come principio: "la installo e me la porto ovunque e funziona sempre uguale"; up-and-running più veloce; estremo minimalismo; Vim deve restare utilizzabile anche senza plugin (nessun plugin manager: non usa Plug).
- Workflow terminal-first: sviluppo nel terminale con vim + git da CLI (adottato `git grep` per cercare nei repo); git, compilazione e debugger già usati separati da Vim; il vero pain point è cercare/aprire i file da Vim → integrazione fzf/grep interna ritenuta necessaria.
- La config che si rompe tra distro è fragilità: la config Emacs "diversa" dopo il passaggio Void→Mint e il desiderio di "qualcosa di più solido" hanno spinto verso il .vimrc one-file; playbook poi portato su Fedora Workstation (ikaros + nymph) con workflow quasi totalmente nel terminale.
- Riproducibilità > comodità grafica: Thunderbird non ha dotfile di configurazione → i feed RSS (elfeed) restano in Emacs "che già funziona".
- Setup dichiarato sul lavoro: workstation Windows + WSL: IDEA o VS Code per il codice, Emacs per gli appunti, Vim nel WSL per le configurazioni.
- In combo con Vim considera già sufficienti ctags + cscope ("praticamente nativi"); tmux per splittare sessioni e usare gdb, make e altri tool su pannelli/window.

## Decisioni pratiche

- **`.vimrc` "Sysdev Portable" (2026-03)**: pensato come config "da vero kernel hacker" ma per sviluppo system in generale (non solo kernel), portabile in pochi secondi su ambienti terzi e robusta su Vim minimale. Impostazioni chiave:
```vim
set nocompatible
set encoding=utf-8
let mapleader=" "
set tabstop=8 shiftwidth=8 softtabstop=8 noexpandtab
set textwidth=80 colorcolumn=81
set incsearch hlsearch ignorecase smartcase gdefault
set updatetime=250 timeoutlen=400
set nolist   " marker whitespace OFF di default, toggle <leader>l
```

- Fix robusto per il bug `$XDG_CACHE_HOME` (Vim creava la cartella letterale `XDG_CACHE_HOME` invece del path risolto):
```vim
set undofile
if has("unix")
  if exists("$XDG_CACHE_HOME") && !empty($XDG_CACHE_HOME)
    let s:cache = $XDG_CACHE_HOME
  else
    let s:cache = expand("~/.cache")
  endif
  let s:ud = s:cache . "/vim/undo//"
  if !isdirectory(s:ud)
    call mkdir(s:ud,"p")
  endif
  execute "set undodir=" . fnameescape(s:ud)
endif
```
- Resto del `.vimrc` finale (rifinito su iterazioni): tema dark "deep black" incorporato nel file (sfondi neri profondi, sintassi migliore di `industry`; temi con sfondo grigio scartati); file manager rimosso ("piena di glitch"); marker whitespace tolti ("quei dannati spazi visualizzati"), riattivabili con `<leader>l`; `rg → grep`; `ctags`; `cscope` se presente; `:ClangFormat`; `:Make` smart; `:Run`; `K` → man. In corso d'opera sistemato l'errore `notermguicolors`.
- **Plugin**: nessun plugin manager; fzf.vim adottato per la navigazione dei file (il pain point dichiarato); fugitive da tenere solo perché fzf.vim ci si integra, non per sostituire git da CLI. Da NON aggiungere (consiglio ChatGPT, per non perdere "una configurazione che puoi clonare ovunque e capire in mezz'ora"): Telescope, lazy.nvim, dashboard, file tree persistenti, decine di plugin LSP, framework completi tipo LazyVim/AstroNvim.
- **Emacs**: tenuta la configurazione attuale invece di passare a Doom Emacs (valutato solo per non rifare la config da capo, con versioning nel playbook); config da snellire per potenziare Org Mode (export in vari formati) e da uniformare tra desktop e workstation; Emacs abilitato su ikaros. Magit + Projectile usati parecchio per aprire i progetti e fare code review, più funzioni custom per lanciare un coding agent AI nella root del progetto ("vibe coding").
- **Editing remoto**: TRAMP già provato ma troppo lento → orientamento: montare il filesystem remoto via sshfs e usare sempre Emacs locale (config, Magit, Projectile, tema/keybinding, agent AI) su path remoti. Pattern consigliato: sshfs per editing comodo, Vim remoto come fallback, clone locale per sviluppo serio (repo grandi → meglio Vim remoto; build/test sul remoto → shell SSH + editor remoto). Escludere `node_modules target build dist vendor .git/objects .cache` (es. `projectile-globally-ignored-directories`); Magit su repo grandi via sshfs va usato con prudenza; mount tipo `-o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,follow_symlinks,cache=yes,kernel_cache,compression=no`.
- **Provato e scartato (evoluzione)**: appunti in Markdown invece di Org (con blocchi di codice; condivisione OneDrive personale + Box di progetto) → riconfermato Org/Emacs; feed RSS spostati in Thunderbird → scartato per riproducibilità, restano in elfeed; Doom Emacs → scartato; evil-mode su Emacs per memoria muscolare → scartata; TRAMP → scartato; file manager nel .vimrc → rimosso; tema `industry`/sfondi grigi → deep black; ipotesi "Emacs per tutto lo sviluppo user-space + Vim solo in remoto" (2026-06-22) → superata dalla convergenza terminale-first con Vim come editor di sviluppo.

## Comparazioni approfondite (sintesi)

- **vi vs vim**: vi (Bill Joy, 1976, BSD) non è più sviluppato davvero; il `vi` di oggi è nvi (macOS/FreeBSD), busybox vi (embedded) o vim in modalità compatibile (su Linux quasi sempre vim); sopravvive solo per compatibilità POSIX. vim (Bram Moolenaar, 1991) aggiunge syntax highlighting, plugin system, vimscript, split, undo multiplo, autocompletion, macro e ampio supporto filetype; sviluppo proseguito anche dopo la morte di Moolenaar (2023).
- **Vim vs Neovim**: Vim vince su disponibilità (su server, rescue, BSD, sistemi minimi e aziendali `vi`/`vim` c'è quasi sempre, `nvim` raramente), config one-file (`scp ~/.vimrc server:` e sei operativo) e stabilità concettuale — un editor "noioso" che non richiede attenzione, con config scritta oggi che funziona ovunque a lungo. Neovim spinge verso Lua, plugin manager, Tree-sitter, LSP, dipendenze esterne e config multi-file: il suo centro di gravità è una piccola distribuzione personale, contrario agli obiettivi di portabilità/prevedibilità dell'utente.
- **Vim vs Emacs**: Vim superiore su editing puro, startup immediato, editing remoto via SSH, ergonomia terminal-first, semplicità mentale — "UNIX sharp tool" per editing opportunistico (`vim /etc/ssh/sshd_config`, `git commit`, `sudoedit /etc/fstab`). Emacs dà il meglio come piattaforma: Projectile, Magit, LSP, terminali, note, RSS, funzioni Lisp, agent di coding — "più vicino a una Lisp machine minimale che a un editor". Verdetto ChatGPT (2026-05-24, domanda "una parola"): Emacs, per il suo profilo di "ambiente operativo"/centro di controllo; l'utente è però poi convergito su Vim per lo sviluppo + Emacs per Org.
- **Stereotipi** (folklore): vim guy = vive nel terminale, tool piccoli componibili UNIX-style, .vimrc portabile, memoria muscolare quasi religiosa, "edita file di configurazione alle 2 di notte su una macchina remota via SSH"; emacs guy = casa digitale, workflow integrale (codice, Git, note, RSS, email, agenda, shell), funzioni Lisp, "Emacs is a great operating system, lacking only a decent editor" → replica: "infatti uso Evil mode". Nella serie Gilfoyle appare su Mac/Ubuntu con WM floating, ma l'utente ne incarna l'approccio pragmatico; Hendricks per ChatGPT ha "energia da vim guy".
- **Audit Emacs** (2026-06-22, nello scenario "Vim editor principale"): vterm si auto-risolve col terminale (tmux/zellij/abduco/dvtm oppure finestre del terminal emulator + workspaces Sway; consiglio: non sostituire vterm con tmux "solo per principio") → nessun motivo forte per tenere Emacs; Org è overkill se usato solo per appunti (basterebbe Markdown in `~/notes` con rg/fzf/glow), vale solo con TODO/agenda/capture/clocking/refile/export/Babel; elfeed sostituibile da tool CLI; il peso reale di Emacs nel workflow = Magit + Projectile + funzioni agent AI.

## Thread aperti

- Tree-sitter per Vim: suggerito come miglioramento più efficace e "invisibile" (parsing accurato per C/Go/Bash senza cambiare modo di lavorare) — adozione da valutare.
- Toolchain C consigliata: `entr` (`find . -name '*.c' | entr -c make test`), `bear` (genera `compile_commands.json` così clangd funziona ovunque), `delta` come pager Git (da rimettere in uso), `btop`.
- Config Vim su tre livelli — core (editing/search/motions) / language (c, go, bash) / local (macchina corrente), con core immutabile e portabile: proposta "architetturale" di ChatGPT, non ancora adottata.
- Investimento consigliato su un solo strumento: padroneggiare GDB, poi `rr` (record & replay: `rr record`, `rr replay`, `reverse-continue`, `reverse-step`); toolbox in ordine: GDB → Valgrind → strace/ltrace → rr → perf/eBPF. rr utile con thread/segnali/programmi concorrenti (APUE avanzata); limiti con funzionalità kernel e hardware particolari.
- Org Mode: configurare l'export multi-formato (obiettivo dichiarato, ancora da fare); snellire in generale la config Emacs.
- sshfs: pattern e funzioni mount/unmount definite in conversazione (opzioni e ignore-dirs), consolidamento nel playbook/workflow ancora aperto.
- Vim Motion su VS Code e IntelliJ: suggerito per consolidare la memoria muscolare, esito non registrato (IdeaVim su IntelliJ invece confermato installato).

## Fonti

| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2026-03-05 → 2026-03-10 | Differenze tra vi e vim | [transcripts/2026-03-05-differenze-tra-vi-e-vim.md](transcripts/2026-03-05-differenze-tra-vi-e-vim.md) |
| 2026-05-24 | Vim vs Emacs | [transcripts/2026-05-24-vim-vs-emacs.md](transcripts/2026-05-24-vim-vs-emacs.md) |
| 2026-06-22 | Emacs vs Terminal Workflow | [transcripts/2026-06-22-emacs-vs-terminal-workflow.md](transcripts/2026-06-22-emacs-vs-terminal-workflow.md) |
| 2026-06-22 → 2026-08-22 | Stereotipi Vim vs Emacs | [transcripts/2026-06-22-stereotipi-vim-vs-emacs.md](transcripts/2026-06-22-stereotipi-vim-vs-emacs.md) |
| 2026-07-15 → 2026-07-21 | Vim vs Neovim | [transcripts/2026-07-15-vim-vs-neovim.md](transcripts/2026-07-15-vim-vs-neovim.md) |
