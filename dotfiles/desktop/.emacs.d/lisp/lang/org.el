;;; org.el -*- lexical-binding: t; -*-

(use-package htmlize
  :ensure t)

;; Setting default directory for Org files.
(setq org-directory "~/Org")

(defvar org-notes-file (expand-file-name "notes.org" org-directory)
  "Default Org notes file.")

(defvar org-calendar-file (expand-file-name "calendar.org" org-directory)
  "Default Org calendar file.")

(use-package org
  :init
  (setq org-clock-mode-line-total 'today
        org-fontify-quote-and-verse-blocks t
        org-indent-mode t
        org-agenda-skip-unavailable-files t
        org-return-follows-link t
        org-startup-folded 'content
        org-todo-keywords '((sequence "🆕(t)" "▶️(s)" "⏳(w)" "🔎(p)" "|" "✅(d)" "🗑(c)" "👨(g)"))
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
           "* 🆕 %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
          ("n" "Note" entry
           (file org-notes-file)
           "* %U %?\n")
          ("e" "Event" entry
           (file org-calendar-file)
           "* %?\nSCHEDULED: %^T\n")))
  :config
  (add-hook 'org-mode-hook 'org-indent-mode))

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
        org-alert-notify-cutoff 10
        org-alert-notify-after-event-cutoff 10
        org-alert-notification-title "Org Agenda")
  (org-alert-enable))

(use-package ob-mermaid
  :ensure t
  :init
  (setq ob-mermaid-cli-path "mmdc")
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((mermaid . t)
     (scheme . t))))

(provide 'org)

;;; org.el ends here
