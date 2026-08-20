;;; keybindings.el --- Native Emacs bindings -*- lexical-binding: t; -*-

(global-set-key (kbd "C-c a") #'org-agenda)
(global-set-key (kbd "C-c c") #'org-capture)

(defvar fscotto/export-map (make-sparse-keymap)
  "Native Emacs prefix map for document exports.")
(global-set-key (kbd "C-c e") fscotto/export-map)
(define-key fscotto/export-map (kbd "p") #'fscotto/org-export-pdf)
(define-key fscotto/export-map (kbd "h") #'fscotto/org-export-html)
(define-key fscotto/export-map (kbd "m") #'fscotto/org-export-markdown)
(define-key fscotto/export-map (kbd "d") #'fscotto/org-export-docx)
(define-key fscotto/export-map (kbd "o") #'fscotto/org-export-odt)

(provide 'core/keybindings)
