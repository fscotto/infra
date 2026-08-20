;;; authoring.el --- Export and document templates -*- lexical-binding: t; -*-

(require 'org)
(require 'ox)
(require 'ox-html)
(require 'ox-latex)
(require 'ox-md)
(require 'ox-odt)

(defconst fscotto/org-templates-directory
  (expand-file-name "templates/org" user-emacs-directory)
  "Directory containing the versioned Org templates.")

(defun fscotto/org--require-current-buffer ()
  "Signal an actionable error unless the current buffer is an Org document."
  (unless (derived-mode-p 'org-mode)
    (user-error "Open an Org file before exporting")))

(defun fscotto/org-export-pdf ()
  "Export the current Org document to PDF with LuaLaTeX and latexmk."
  (interactive)
  (fscotto/org--require-current-buffer)
  (dolist (program '("latexmk" "lualatex"))
    (unless (executable-find program)
      (user-error "%s is not available; install the authoring dependencies" program)))
  (org-latex-export-to-pdf))

(defun fscotto/org-export-html ()
  "Export the current Org document to HTML5."
  (interactive)
  (fscotto/org--require-current-buffer)
  (org-html-export-to-html))

(defun fscotto/org-export-markdown ()
  "Export the current Org document to Markdown."
  (interactive)
  (fscotto/org--require-current-buffer)
  (org-md-export-to-markdown))

(defun fscotto/org-export-docx ()
  "Export the current Org document to DOCX through Pandoc."
  (interactive)
  (fscotto/org--require-current-buffer)
  (unless (buffer-file-name)
    (user-error "Save the Org file before exporting it to DOCX"))
  (let ((pandoc (executable-find "pandoc"))
        (output (concat (file-name-sans-extension (buffer-file-name)) ".docx")))
    (unless pandoc
      (user-error "pandoc is not available; install the authoring dependencies"))
    (save-buffer)
    (unless (zerop (call-process pandoc nil "*Org Pandoc*" nil
                                 (buffer-file-name) "-f" "org" "-t" "docx" "-o" output))
      (pop-to-buffer "*Org Pandoc*")
      (user-error "Pandoc could not export this document"))
    (message "DOCX exported to %s" output)))

(defun fscotto/org-export-odt ()
  "Export the current Org document to OpenDocument Text."
  (interactive)
  (fscotto/org--require-current-buffer)
  (org-odt-export-to-odt))

(defun fscotto/org-copy-template (template)
  "Copy a versioned TEMPLATE into `org-directory'."
  (interactive
   (list (completing-read "Template: "
                          '("documentation.org" "cv.org" "generic-document.org") nil t)))
  (let ((source (expand-file-name template fscotto/org-templates-directory))
        (destination (expand-file-name template org-directory)))
    (unless (file-exists-p source)
      (user-error "Template not found: %s" source))
    (make-directory org-directory t)
    (copy-file source destination nil)
    (find-file destination)))

(provide 'authoring)
