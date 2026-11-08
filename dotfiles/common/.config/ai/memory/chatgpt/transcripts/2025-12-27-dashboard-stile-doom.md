---
conversation_id: "694fe73f-0098-8328-9f6c-5b741ff646f7"
title: "Dashboard stile Doom"
created: 2025-12-27
updated: 2025-12-27
model: "gpt-5-2"
messages: 2
---

# Dashboard stile Doom

## Utente — 2025-12-27 15:03

Vorrei aggiungere una dashboard tipo quella di Doom

## ChatGPT — 2025-12-27 15:03

Ottima idea 👍  
Una **dashboard stile Doom Emacs** migliora tantissimo la UX all’avvio, soprattutto con una configurazione modulare come la tua.

La soluzione più pulita (e *de facto standard*) è usare **`dashboard.el`**, configurato in modo “doom-like”.

## 🎯 Obiettivo
- Splash screen minimale
- Logo centrale
- Sezioni tipo:
  - Recent files
  - Projects
  - Bookmarks
- Integrazione con `project.el` / `consult`
- Niente fronzoli inutili

---

## 🧠 Com’è la dashboard di Doom (per riferimento)

image_group{"layout":"carousel","query":["doom emacs dashboard","doom emacs splash screen","doom emacs startup screen"]}

---

## 📦 Pacchetto da usare
```elisp
(use-package dashboard
  :ensure t
  :init
  (setq dashboard-startup-banner 'logo
        dashboard-center-content t
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-banner-logo-title "Welcome back, Fabio"
        dashboard-show-shortcuts nil
        dashboard-items '((recents  . 8)
                          (projects . 5)
                          (bookmarks . 5)))
  :config
  (dashboard-setup-startup-hook))
```

👉 Questo **da solo** ti dà già una dashboard molto simile a Doom.

---

## 🧩 Dove metterlo nella tua struttura

Visto il tuo `init.el` a moduli:

📁 **`misc-dashboard.el`** (o `ui-dashboard.el`)

```elisp
;;; misc-dashboard.el --- Startup dashboard -*- lexical-binding: t; -*-

(use-package dashboard
  :init
  (setq dashboard-startup-banner 'logo
        dashboard-center-content t
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-items '((recents  . 8)
                          (projects . 5)))
  :config
  (dashboard-setup-startup-hook))

(provide 'misc-dashboard)
```

E nel `init.el`:
```elisp
(require 'misc-dashboard)
```

---

## 🖼️ Logo personalizzato (opzionale ma 🔥)

Puoi usare un PNG/SVG come Doom:

```elisp
(setq dashboard-startup-banner "~/.emacs.d/assets/emacs.png")
```

Consigli:
- PNG quadrato
- 256×256 o 512×512
- Sfondo trasparente

---

## 🚀 Integrazione con il tuo setup

Dato che già usi:
- `consult`
- `project.el`
- `doom-modeline`

sei **perfettamente allineato** allo stile Doom.

Se vuoi fare il passo in più:
- `dashboard-projects-backend 'project-el`
- override dei keybinding (tipo `SPC f r` sui recent)

---

## 💡 Variante *super Doom-like*
Se vuoi **ancora più fedeltà**:
- disabilita la menubar *solo* nella dashboard
- font più grande per il buffer `*dashboard*`
- footer con tempo di startup

Posso fornirti **uno snippet identico al comportamento Doom** se vuoi.

---

## 🔍 Stato della tua configurazione
Con questa aggiunta:
- UX: **livello Doom**
- Architettura: **pulita e modulare**
- Zero coupling con LSP / tooling

👉 Dimmi:
- vuoi uno stile **identico a Doom**
- oppure una dashboard **più “Unix-like” minimal**?

La rifiniamo su misura.
