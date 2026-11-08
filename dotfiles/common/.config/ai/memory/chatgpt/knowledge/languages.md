# Linguaggi — scripting di sistema e Go

> Distillato dalle conversazioni ChatGPT elencate in fondo (transcript completi in ~/.config/ai/memory/chatgpt/transcripts/).
> Generato da scripts/chatgpt_export_to_memory.py + distillazione AI, 2026-11-08.

## Posizioni e preferenze sui linguaggi di scripting

- Sintesi del confronto system programming (C vs C++/Rust/Zig/Go): **C come linguaggio principale**, **Bash/Python di supporto** per lo scripting.
- Conclusione: lo studio di C e della programmazione di sistema Linux user-space vale per ogni percorso; divergono solo gli approfondimenti kernel vs Docker/sistemi distribuiti.
- Bash: fondamentale su Unix/Linux (startup, deploy, backup, catene di comandi); nel piano: *Linux Command Line and Shell Scripting Bible*.
- Python: universale per automazione/orchestrazione (Ansible, Fabric); nel piano: *Automate the Boring Stuff with Python*.
- Perl: storico "glue language" (text processing, sysadmin); in panoramica, non nel piano finale. PowerShell solo per amministrazione Windows (Core cross-platform); Ruby nota per DevOps (Chef/Puppet): nessuno dei due adottato.
- Go: compilato, performante, con concurrency (CLI, microservizi, DevOps); compare tra i linguaggi del piano (C, Bash, Python, Go, Zig); Clojure presente solo nella prima stesura del piano.
- Piano C su 12 settimane: *Linux System Programming* 2ª ed. + *APUE* 3ª ed. integrata per settimana (processi 8-10, thread 12-13, memoria 14, segnali 11, socket 16, shell/daemon 13.6+17-19) + *OSTEP* (scheduling, VM, FS).
- Esercizi pratici cumulativi per settimana: mycp, tree con readdir, downloader multithread, allocator con mmap, gestione segnali, echo server TCP IPv4, chat server select/epoll, mini-shell finale; diario di apprendimento in Markdown.
- Evoluzione piano: variante "Kernel Hacker" aggiunge *Linux Kernel Programming* Part 1 e 2 in Fase 3 e sposta *Designing Data-Intensive Applications* in Fase 4 opzionale; decisione di mantenere LSP e APUE insieme.
- Avanzamento: *Linux System Programming* 2ª ed. letto fino ai capitoli su file I/O, I/O avanzato e processi; possiede *APUE* 3ª ed.

## Toolchain Go (configurazione, decisioni, fix)

- Obiettivi dichiarati per l'ambiente di sviluppo: autocompletamento, analisi statica, debugger e formatter (tranne in C); linguaggi C, Go, Python, Bash; approccio "consapevole e non magico".
- Stato iniziale (2025-12): lsp-mode e autocompletamento globale (company/corfu) funzionanti, ma Go era "plain editing": nessun mode Go, nessun hook Go→LSP, nessun debugger Delve, nessun formatter, nessuna analisi statica.
- Setup target minimale: `go-ts-mode` (Emacs 29+), `gopls` (LSP + staticcheck/govet), formatter `gofmt`/`goimports`, debugger `delve` via `dap-mode`.
- go.mod/go.sum: gestione dedicata richiesta → `go-mod-ts-mode`; grammatica tree-sitter `gomod` installata dopo errore treesit (libtree-sitter-gomod assente in ~/.emacs.d/tree-sitter); associazioni errate (go.mod→modula-2, go.sum→fundamental) corrette a mano dall'utente.
- Format-on-save Go: falliva per funzione assente `fscotto/go-format-on-save`; sistemata → formattazione al salvataggio funzionante.
- Debug: template "Go :: Debug test at point (auto)" produceva "Unknown JSON error" (lambda in `:args`) e warning LSP "Currently active thread is not stopped"; sostituito da 3 template su `dap-go` ("Debug all tests", "Debug package tests", "Debug single test"); debugger verificato funzionante dall'utente.
- Preferenza stabile: le patch dell'assistente non funzionano ("malformed") → l'utente applica le modifiche a mano su init.el.
- Lint: architettura `gopls` (analisi semantica + quick fixes) + `flycheck` (aggregatore diagnostiche) + `golangci-lint` (lint), gopls affiancato e non sostituito.
- Fix chiave: `(flycheck-add-next-checker 'lsp 'golangci-lint)` fallisce perché `lsp` non è un checker Flycheck; le diagnostiche LSP entrano via `lsp-diagnostics-provider :flycheck`.

## Configurazioni finali

init.el — Go: mode, LSP e debug applicati e verificati; lint = soluzione conclusiva consigliata.

```elisp
(use-package go-ts-mode
  :mode "\\.go\\'")
(add-hook 'go-ts-mode-hook #'lsp-deferred)
(setq lsp-diagnostics-provider :flycheck)

;; Debug (dap-mode + delve): template finali
(with-eval-after-load 'dap-go
  ;; Debug all tests in module
  (dap-register-debug-template
   "Go :: Debug all tests"
   (list :type "go"
         :request "launch"
         :name "Go :: Debug all tests"
         :mode "test"
         :program "${workspaceFolder}"
         :cwd "${workspaceFolder}"))
  ;; + "Go :: Debug package tests" (program/cwd: ${fileDirname})
  ;; + "Go :: Debug single test" (test scelto con prompt)
  )

;; Lint: golangci-lint checker principale per Go, solo al salvataggio
(with-eval-after-load 'flycheck
  (add-hook 'go-ts-mode-hook
            (lambda ()
              (setq-local flycheck-checker 'golangci-lint)
              ;; evita lint continuo, solo su save
              (setq-local flycheck-check-syntax-automatically '(save mode-enabled))
              (flycheck-mode 1))))
```

Linter (fuori da Emacs; deve stare nel PATH di Emacs, altrimenti exec-path-from-shell):

```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

`.golangci.yml` proposto, a root del modulo Go ("serio, non pedante, molto usato in produzione"):

```yaml
run:
  timeout: 2m
  tests: false
linters:
  disable-all: true
  enable:
    - govet
    - errcheck
    - staticcheck
    - ineffassign
    - unused
    - gosimple
linters-settings:
  errcheck:
    check-type-assertions: true
    check-blank: true
issues:
  exclude-use-default: false
  max-issues-per-linter: 50
  max-same-issues: 10
```

Trade-off della soluzione lint: le diagnostiche di gopls non compaiono più in Flycheck; LSP continua a fornire hover, code actions, rename.

## Thread aperti

- Reintrodurre eventualmente le diagnostiche gopls anche nell'UI di Flycheck (lasciato in sospeso).
- Chaining opzionale `(flycheck-add-next-checker 'go-build 'golangci-lint)`: fattibile solo se esiste il checker `go-build`; verificare con `M-x flycheck-verify-setup`.
- Layout di debug Emacs simile a IntelliJ: richiesto, esito non documentato nel digest.
- Scelta finale del percorso kernel vs Docker/sistemi distribuiti: rimandata ("ne parliamo quando sarà di scegliere il percorso").
- Esecuzione del piano 12 settimane (LSP+APUE+OSTEP) con relativo diario in Markdown.

## Fonti

| Data | Conversazione | Transcript |
| --- | --- | --- |
| 2025-07-10 | Linguaggi scripting sistema | [2025-07-10-linguaggi-scripting-sistema.md](transcripts/2025-07-10-linguaggi-scripting-sistema.md) |
| 2025-12-16 | Configurazione Go incompleta | [2025-12-16-configurazione-go-incompleta.md](transcripts/2025-12-16-configurazione-go-incompleta.md) |
