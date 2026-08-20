;;; which-key.el --- Discoverable native bindings -*- lexical-binding: t; -*-

(require 'use-package)

(use-package which-key
  :ensure t
  :defer 1
  :config
  (which-key-mode)
  (setq which-key-idle-delay 0.45
        which-key-idle-secondary-delay 0.05
        which-key-max-display-columns 3
        which-key-max-description-length 45)
  (which-key-add-key-based-replacements
    "C-c a" "Org agenda"
    "C-c c" "Org capture"
    "C-c e" "Document export"
    "C-c e p" "Export PDF"
    "C-c e h" "Export HTML"
    "C-c e m" "Export Markdown"
    "C-c e d" "Export DOCX"
    "C-c e o" "Export ODT"
    "C-c r" "RSS (Elfeed)"
    "C-x C-b" "Ibuffer"))

(provide 'misc/which-key)
