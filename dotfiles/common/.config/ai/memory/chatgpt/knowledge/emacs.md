# Emacs

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Decisioni e preferenze stabili

- Emacs custom (nessuna distribuzione), orientato ad authoring: org-mode, mu4e, elfeed, documenti; sviluppo C/Go con LSP+DAP; Vim resta l'editor primario di sviluppo (Emacs è complementare); la .emacs.d è gestita dal playbook Ansible dei dotfiles.
- UX in stile Doom Emacs (lo usa su un'altra macchina Windows): leader `C-c`, sottomenu descrittivi con `which-key` e etichette per i prefissi (es. `C-c g` = "git"); preferisce funzionalità e menu ordinate al "purismo".
- Completion: `company` + `company-capf`; `corfu` rifiutato esplicitamente (già provato su Doom, non è piaciuto); `company-lsp` non serve, lsp-mode integra già il backend.
- Keybinding = infrastruttura: centralizzati in `core/keybindings`, sempre caricati e PRIMA dei moduli che dipendono dai prefissi `C-c`.
- Binding contestuali, non globali: mappa LSP visibile solo nei buffer con LSP attivo, mappa DAP solo con `dap-mode` attivo; pattern: keymap "muta" + `autoload` + `local-set-key` buffer-local via hook.
- Struttura modulare `~/.emacs.d/lisp/` con moduli `core-*`, `tools-*`, `lang-*`, `misc-*`; `init.el` = manifesto dichiarativo (principio: se cresce oltre 30-40 righe, qualcosa non va).
- Python e Bash usati solo per script semplici mono-file: configurazione volutamente essenziale, no over-engineering.
- Formattazione C: approccio custom, resta volontariamente parziale.
- Tree-sitter = "una scelta, non un dogma": usabile insieme ai major mode classici dove serve davvero.
- Stack finale documentato: lsp-mode + clangd, dap-mode + dap-cpptools, magit, consult + consult-lsp, project.el, doom-modeline, which-key, company, flycheck, vterm, elfeed, mu4e, org-mode (org-directory `~/Remotes/pCloud/Org`).

## Configurazioni e stati finali

- Ordine/caricamento moduli (`init.el`):
  ```elisp
  (require 'core-packages) (require 'core-ui) (require 'core-editor)
  (require 'core-performance)
  (require 'core-keybindings)   ;; NON opzionale: prima di tutto ciò che usa C-c
  ;; poi: which-key, tools-completion, tools-lsp, tools-dap, tools-project, vcs, lang/*, misc/*
  ```
- Load dichiarativo dei moduli da mappa:
  ```elisp
  (defconst fscotto/modules-dir (expand-file-name "lisp" user-emacs-directory))
  (defun fscotto/load-module (module)
    "Carica un modulo dato come simbolo, es. 'core/packages."
    (let* ((module-name (symbol-name module))
           (path (expand-file-name (concat module-name ".el") fscotto/modules-dir)))
      (unless (file-exists-p path) (error "Modulo non trovato: %s" path))
      (load path nil 'nomessage)))
  ```
- Leader keymap: `C-c` → `fscotto/leader-map`; sottomappe: `v` version-control, `o` open (`T` vterm, `m` mu4e, `f` elfeed), `g` git/Magit (`s` status, `b` branch, `c` commit, `p` push, `f` fetch), `l` LSP, `d` DAP.
- Mappa LSP `C-c l`: `s` consult-lsp-symbols, `e` consult-lsp-diagnostics, `d` find-definition, `D` type-definition, `i` implementation, `a` code-action, `r` rename, `f` format-buffer, `R` restart-workspace.
- Mappa DAP `C-c d`: `d` dap-debug, `b` breakpoint-toggle, `c` continue, `n` next, `i` step-in, `o` step-out, `r` restart-frame, `q` disconnect.
- Pattern keymap contestuale (LSP; identico per DAP con `dap-mode` su `dap-mode-hook` + `dap-session-created-hook` + `dap-terminated-hook`):
  ```elisp
  (defvar fscotto/lsp-map (make-sparse-keymap))   ;; NON legarla subito a C-c l
  (autoload 'lsp-find-definition "lsp-mode" nil t) ;; ecc. per ogni comando
  (defun fscotto/enable-lsp-keymap ()
    (when (and (bound-and-true-p lsp-mode) (lsp-workspaces))
      (local-set-key (kbd "C-c l") fscotto/lsp-map)))
  (add-hook 'lsp-mode-hook #'fscotto/enable-lsp-keymap)
  ```
- Tree-sitter su Emacs 29.3 / Linux Mint: grammatiche compilate da Emacs, NON le .so di sistema (che danno `version-mismatch: 15`):
  ```elisp
  (setq treesit-extra-load-path (list (expand-file-name "tree-sitter" user-emacs-directory)))
  (setq treesit-font-lock-level 4)
  (setq major-mode-remap-alist '((c-mode . c-ts-mode) (c++-mode . c++-ts-mode)
                                 (python-mode . python-ts-mode) (bash-mode . bash-ts-mode)))
  ;; treesit-language-source-alist: c, cpp, python, bash, go (repo GitHub tree-sitter)
  ```
  Installazione grammatiche: `M-x treesit-install-language-grammar` per c, cpp, go, python, bash; dipendenze sistema su Mint: `build-essential` + `git` (più eventualmente make/cmake).
- LSP Bash: server `bash-language-server` installato con `npm install -g bash-language-server`; `(add-hook 'sh-mode-hook #'lsp)`; company (min-prefix 1, idle-delay 0.0), flycheck; shfmt via `reformatter` (args `-i 2 -ci`, `shfmt-format-on-save-mode`); yasnippet opzionale.
- Debug C: DAP con `require 'dap-cpptools` agganciato al caricamento di dap-mode; funzionante con il template di debug salvato nel progetto secondo https://emacs-lsp.github.io/dap-mode/page/configuration/#dap-cpptools.
- Look&feel stabile: tema `wombat`, font "Iosevka Nerd Font 14", toolbar/menu/scrollbar off, frame massimizzati, startup/splash screen off, `y-or-n-p`, `fill-column` 120, `undo-limit` 8000000 / `undo-strong-limit` 12000000, `scroll-step` 3, ring-bell ignorato, column-number e display-time attivi, numeri di riga solo in prog-mode/conf-mode.
- Avvio: gc-cons-threshold elevato temporaneamente durante l'init e `file-name-handler-alist` disabilitato durante l'avvio (startup speed tweaks).
- which-key: `which-key-mode`, idle-delay 0.5, etichette prefissi con `which-key-add-key-based-replacements` (es. "C-c g" → "git").

## Evoluzione nel tempo

- 2025-09 (task coverage): valutati task quotidiani copribili con Emacs — bene: email (mu4e), Telegram (telega.el), PDF/EPUB (pdf-tools, nov.el), sviluppo; parziale: browsing (eww/w3m), Spotify/VLC solo controllo; meglio esterni: browser pesante, WhatsApp, Discord. RSS: adottato elfeed (+elfeed-org/elfeed-webkit come opzioni), scartati Gnus/nnrss, feedly.el, org-feed.
- 2025-09 (kernel dev): confronto Emacs vs Neovim per sviluppo kernel Linux — entrambi validi; Vim/Neovim più popolare tra kernel hacker (stima sondaggi 60-70% vs 20-25%); Emacs forte su debug integrato (GUD/realgud), magit, progetti complessi; Neovim più reattivo su file enormi; consigli: lsp-mode/ccls, realgud, projectile+magit, diff-hl, indentazione kernel-style.
- 2025-12-12 → 2026-01-10 (ottimizzazione): da init.el monolitico a config consolidata via revisioni iterative: analisi config, which-key + etichette stile Doom, keybinding tipo Doom, projectile con menu Doom-like, Magit con keybinding (priorità dichiarata sopra il "purismo"), chiarimenti ivy vs counsel/vertico/consult, consult-lsp, tuning clangd; setup sviluppo C completato, poi Go portato "allo stesso livello di C"; stack di fine dicembre: consult, project.el, doom-modeline.
- Provati e scartati in itinere: opzioni clangd invalide `--header-insertion-decorations=0`, `--limit-result=500`, `--limit-references=2000` (bloccavano l'avvio del server, poi rimosse — nota: lsp parte sia da c-mode che da c-ts-mode); grammatiche tree-sitter .so di distro su Mint (Emacs 29.3, `version-mismatch: 15`); undo-limit 2000000/undo-strong-limit 4000000000 (finali: 8000000/12000000); corfu; config tutta in un unico init.el (ingestibile dopo 2-3 mesi).
- Errori DAP superati: `dap-version` non trovato, `Undefined command: "Content-Length"` nel buffer GDB::Run, `waiting for v8 protocol on stdin/stdout` → risolti con il template ufficiale dap-cpptools caricato nel progetto.
- 2025-12-22 (modularizzazione): split dell'init.el reale in moduli core→tools→lang→misc (originale conservato in `init.el.bak`); regressione post-split "menu Git sotto C-c sparito" = `core-keybindings` non incluso → fix con `require` esplicito; prefissi resi espliciti in core-keybindings (`define-prefix-command 'fscotto/git-map` su `C-c g`, `'fscotto/project-map` su `C-c p`), moduli agganciano solo comandi; early-init.el proposto come opzionale (Emacs 27+).
- 2025-12-23 (load dichiarativo): `fscotto/load-module` rende init.el un manifesto; chiarita la semantica di `with-eval-after-load` (i binding nascono solo al primo effettivo utilizzo della feature, es. vterm si caricava mentre elfeed/mu4e no); migrazione verso binding contestuali per git, LSP, DAP e `C-c C-t vterm-copy-mode` solo nei buffer vterm.
- 2025-12-27: proposta dashboard stile Doom con dashboard.el.

## Thread aperti

- Dashboard stile Doom: snippet `dashboard.el` proposto (logo, center-content, heading/file icons, banner title "Welcome back, Fabio", recents 8 / projects 5 / bookmarks 5, modulo `misc-dashboard.el` + `require`, opzionali `dashboard-projects-backend 'project-el` e override stile `SPC f r`, logo PNG in `~/.emacs.d/assets/`); resta da scegliere "identico a Doom" vs "minimal Unix-like".
- Configurazione in formato org (config.org fonte unica + org-babel-tangle per generare i .el): proposta, poi rimandata ("facciamo prima lo split dei file").
- Keymap git visibile solo all'interno di progetti git: richiesta e discussa, esito finale non documentato.
- Calendario in Emacs: valutati Calfw, org-gcal, org-caldav-ics, khalel (vdirsyncer+khal), org-timeblock.el/org-hyperscheduler; nessuna adozione documentata.
- early-init.el e profili: discussione avviata ("Proviamo"), esito non documentato.
- Tree-sitter vs major mode classici: panoramica completata (pro: parsing strutturale, sinergia con clangd, editing strutturale, performance su file grandi, futuro Emacs 29+; contro: dipendenze esterne + ABI, debug più difficile); nessuna scelta finale esplicita.

## Fonti
| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-09-05 | Task Emacs coverage | [transcripts/2025-09-05-task-emacs-coverage.md](transcripts/2025-09-05-task-emacs-coverage.md) |
| 2025-09-06 | Emacs per sviluppo kernel | [transcripts/2025-09-06-emacs-per-sviluppo-kernel.md](transcripts/2025-09-06-emacs-per-sviluppo-kernel.md) |
| 2025-12-12 | Ottimizzazione configurazione Emacs | [transcripts/2025-12-12-ottimizzazione-configurazione-emacs.md](transcripts/2025-12-12-ottimizzazione-configurazione-emacs.md) |
| 2025-12-15 | Configurazione LSP Bash | [transcripts/2025-12-15-configurazione-lsp-bash.md](transcripts/2025-12-15-configurazione-lsp-bash.md) |
| 2025-12-22 | Modularizzare configurazione Emacs | [transcripts/2025-12-22-modularizzare-configurazione-emacs.md](transcripts/2025-12-22-modularizzare-configurazione-emacs.md) |
| 2025-12-23 | Load moduli dichiarativo Emacs | [transcripts/2025-12-23-load-moduli-dichiarativo-emacs.md](transcripts/2025-12-23-load-moduli-dichiarativo-emacs.md) |
| 2025-12-27 | Dashboard stile Doom | [transcripts/2025-12-27-dashboard-stile-doom.md](transcripts/2025-12-27-dashboard-stile-doom.md) |