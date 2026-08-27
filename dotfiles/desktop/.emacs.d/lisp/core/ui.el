;;; ui.el --- Authoring UI -*- lexical-binding: t; -*-

;; Keep the established desktop appearance while leaving IDE-specific UI out.
(require 'use-package)
(use-package nordic-night-theme
  :ensure t
  :config
  (load-theme 'nordic-night t))

(defconst fscotto/default-font
  (pcase system-type
    ('gnu/linux "UbuntuSansMono Nerd Font 14")
    ('windows-nt "JetBrainsMono NF 12")
    (_ "monospace 14"))
  "Default font for graphical Emacs frames on the current platform.")

(set-frame-font fscotto/default-font nil t)
(add-to-list 'default-frame-alist `(font . ,fscotto/default-font))
(add-to-list 'default-frame-alist '(fullscreen . maximized))

(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(setq inhibit-startup-screen t
      inhibit-splash-screen t
      fill-column 120
      undo-limit 8000000
      undo-strong-limit 12000000
      scroll-step 3
      ring-bell-function 'ignore)
(defalias 'yes-or-no-p 'y-or-n-p)
(column-number-mode)
(display-time)

(provide 'core/ui)
