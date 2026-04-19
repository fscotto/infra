;;; org.el -*- lexical-binding: t; -*-

(use-package htmlize
  :ensure t)

(use-package org
  :init
  (setq org-clock-mode-line-total 'today
        org-fontify-quote-and-verse-blocks t
        org-indent-mode t
        org-return-follows-link t
        org-startup-folded 'content
        org-todo-keywords '((sequence "🆕(t)" "▶️(s)" "⏳(w)" "🔎(p)" "|" "✅(d)" "🗑(c)" "👨(g)"))
        org-export-backends '(html latex odt md ascii icalendar)
        org-latex-pdf-process '("pdflatex -interaction nonstopmode %f"
                                "pdflatex -interaction nonstopmode %f")
        org-latex-default-class "article"
        org-html-doctype "html5"
        org-html-html5-fancy t)
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

(use-package ob-mermaid
  :ensure t
  :init
  (setq ob-mermaid-cli-path "mmdc")
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((mermaid . t)
     (scheme . t))))


;; Setting default directory for Org files
(setq org-directory "~/Org")

(provide 'org)

;;; org.el ends here
