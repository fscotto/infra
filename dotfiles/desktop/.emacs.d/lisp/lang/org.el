;;; org.el --- Org authoring workflow -*- lexical-binding: t; -*-

(require 'org)
(require 'org-capture)
(require 'org-agenda)
(require 'org-id)
(require 'org-tempo)
(require 'ox)
(require 'ox-html)
(require 'ox-latex)
(require 'ox-md)
(require 'ox-odt)

(setq org-directory (expand-file-name "Org" (getenv "HOME"))
      org-default-notes-file (expand-file-name "inbox.org" org-directory)
      org-agenda-files (list org-default-notes-file
                             (expand-file-name "agenda.org" org-directory)
                             (expand-file-name "notes.org" org-directory)
                             (expand-file-name "meetings" org-directory)
                             (expand-file-name "projects" org-directory))
      org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "WAIT(w)" "|" "DONE(d)" "CANCELLED(c)"))
      org-tag-alist '((:startgroup) ("work" . ?w) ("personal" . ?p) ("meeting" . ?m)
                      ("documentation" . ?d) (:endgroup))
      org-startup-indented t
      org-startup-folded 'content
      org-hide-leading-stars t
      org-hide-emphasis-markers t
      org-return-follows-link t
      org-src-fontify-natively t
      org-src-tab-acts-natively t
      org-fontify-quote-and-verse-blocks t
      org-export-with-smart-quotes t
      org-html-doctype "html5"
      org-html-html5-fancy t
      org-html-head-include-default-style nil
      org-html-head "<link rel=\"stylesheet\" href=\"org.css\" type=\"text/css\" />"
      org-latex-compiler "lualatex"
      org-latex-pdf-process '("latexmk -lualatex -interaction=nonstopmode -output-directory=%o %f"))

;; Keep the LuaLaTeX dependency set small while retaining text, tables, links,
;; and images in exported documents.
(setq org-latex-default-packages-alist
      '(("" "amsmath" t ("lualatex" "xetex"))
        ("" "fontspec" t ("lualatex" "xetex"))
        ("" "graphicx" t)
        ("" "longtable" nil)
        ("" "hyperref" nil)))

(setq org-capture-templates
      `(("t" "TODO" entry (file ,org-default-notes-file)
         "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
        ("n" "Note" entry (file ,(expand-file-name "notes.org" org-directory))
         "* %U %?\n")
        ("m" "Meeting" entry (file+olp+datetree ,(expand-file-name "meetings/meetings.org" org-directory))
         "* %^{Title} :meeting:\n%U\n%?\n")
        ("d" "Document idea" entry (file ,(expand-file-name "documentation/ideas.org" org-directory))
         "* IDEA %? :documentation:\n%U\n")))

(add-hook 'org-mode-hook #'org-indent-mode)
(add-hook 'org-mode-hook #'visual-line-mode)
(add-hook 'org-mode-hook #'flyspell-mode)

(org-babel-do-load-languages
 'org-babel-load-languages
 '((shell . t)
   (python . t)
   (C . t)))

(provide 'lang/org)
