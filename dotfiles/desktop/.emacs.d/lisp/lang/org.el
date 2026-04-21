;;; org.el -*- lexical-binding: t; -*-

(use-package htmlize
  :ensure t)

;; Setting default directory for Org files.
(setq org-directory "~/Org")

(defvar org-notes-file (expand-file-name "notes.org" org-directory)
  "Default Org notes file.")

(defvar org-calendar-file (expand-file-name "calendar.org" org-directory)
  "Default Org calendar file.")

(defface +org-todo-active
  '((t (:foreground "#51afef" :weight bold)))
  "Face for active Org TODO states.")

(defface +org-todo-project
  '((t (:foreground "#c678dd" :weight bold)))
  "Face for project Org TODO states.")

(defface +org-todo-onhold
  '((t (:foreground "#ECBE7B" :weight bold)))
  "Face for waiting Org TODO states.")

(defface +org-todo-cancel
  '((t (:foreground "#ff6c6b" :weight bold)))
  "Face for cancelled Org TODO states.")

(use-package org
  :init
  (setq org-clock-mode-line-total 'today
        org-fontify-done-headline t
        org-fontify-quote-and-verse-blocks t
        org-indent-mode t
        org-agenda-skip-unavailable-files t
        org-return-follows-link t
        org-src-fontify-natively t
        org-src-tab-acts-natively t
        org-startup-folded 'content
        org-hide-leading-stars t
        org-hide-emphasis-markers t
        org-id-link-to-org-use-this t
        org-id-track-globally t
        org-todo-keywords
        '((sequence
           "TODO(t)"
           "PROJ(p)"
           "LOOP(r)"
           "STRT(s)"
           "WAIT(w)"
           "HOLD(h)"
           "IDEA(i)"
           "|"
           "DONE(d)"
           "KILL(k)")
          (sequence
           "[ ](T)"
           "[-](S)"
           "[?](W)"
           "|"
           "[X](D)")
          (sequence
           "|"
           "OKAY(o)"
           "YES(y)"
           "NO(n)"))
        org-todo-keyword-faces
        '(("[-]"  . +org-todo-active)
          ("STRT" . +org-todo-active)
          ("[?]"  . +org-todo-onhold)
          ("WAIT" . +org-todo-onhold)
          ("HOLD" . +org-todo-onhold)
          ("PROJ" . +org-todo-project)
          ("NO"   . +org-todo-cancel)
          ("KILL" . +org-todo-cancel))
        org-export-backends '(html latex odt md ascii icalendar)
        org-latex-pdf-process '("pdflatex -interaction nonstopmode %f"
                                "pdflatex -interaction nonstopmode %f")
        org-latex-default-class "article"
        org-html-doctype "html5"
        org-html-html5-fancy t
        org-default-notes-file (expand-file-name "inbox.org" org-directory)
        org-agenda-files (mapcar (lambda (file)
                                   (expand-file-name file org-directory))
         '("inbox.org" "tasks.org" "calendar.org" "notes.org"))
        org-capture-templates
        '(("t" "Task" entry
           (file org-default-notes-file)
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
          ("n" "Note" entry
           (file org-notes-file)
           "* %U %?\n")
          ("e" "Event" entry
           (file org-calendar-file)
           "* %?\nSCHEDULED: %^T\n")))
  :config
  (require 'org-tempo)
  (require 'org-id)
  (require 'org-protocol)
  (add-to-list 'org-src-lang-modes '("go" . go-ts))
  (add-to-list 'org-src-lang-modes '("rust" . rust-ts))
  (add-hook 'org-mode-hook 'org-indent-mode))

(use-package org-appear
  :ensure t
  :hook (org-mode . org-appear-mode))

(use-package org-bullets
  :ensure t
  :init
  (setq org-bullets-bullet-list '("❯" "❯❯" "❯❯❯" "❯❯❯❯" "❯❯❯❯❯"))
  :config
  (add-hook 'org-mode-hook 'org-bullets-mode))

(use-package org-re-reveal
  :ensure t
  :init
  (setq org-re-reveal-transition 'none
        org-re-reveal-theme "dracula"))

(use-package org-alert
  :ensure t
  :after org
  :config
  (setq alert-default-style 'libnotify
        org-alert-interval 300
        org-alert-notify-cutoff 5
        org-alert-notify-after-event-cutoff 10
        org-alert-notification-title "Org Agenda")
  (add-hook 'org-agenda-mode-hook #'org-alert-enable))

(use-package ob-mermaid
  :ensure t
  :init
  (setq ob-mermaid-cli-path (or (executable-find "mmdc") "mmdc")))

(use-package ob-go
  :ensure t
  :after org)

(use-package ob-rust
  :ensure t
  :after org)

(provide 'lang/org)

(with-eval-after-load 'org
  (require 'ob-C)
  (require 'ob-emacs-lisp)
  (require 'ob-go)
  (require 'ob-perl)
  (require 'ob-python)
  (require 'ob-rust)
  (require 'ob-shell)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((C       . t)
     (emacs-lisp . t)
     (go      . t)
     (perl    . t)
     (python  . t)
     (rust    . t)
     (shell   . t))))

;;; org.el ends here
