;;; documents.el -*- lexical-binding: t; -*-

(use-package pdf-tools
  :ensure t
  :config
  (pdf-tools-install))

(use-package pdf-view
  :config
  (setq-default pdf-view-display-size 'fit-width)
  (setq pdf-cache-org-imgparams t
        pdf-view-use-smooth-scrolling t)
  (setq pdf-annot-default-visible-properties t))

(with-eval-after-load 'pdf-view
  (define-key pdf-view-mode-map (kbd "n") 'pdf-view-next-page)
  (define-key pdf-view-mode-map (kbd "p") 'pdf-view-previous-page)
  (define-key pdf-view-mode-map (kbd "q") 'pdf-view-close))

(use-package nov
  :ensure t
  :mode ("\\.epub\\'" . nov-mode))

(use-package calibre
  :ensure t
  :commands calibre-library
  :config
  (setq calibre-calibredb-executable
        (or (executable-find "calibredb")
            (let ((flatpak-wrapper (expand-file-name "~/.local/bin/calibredb")))
              (when (file-executable-p flatpak-wrapper)
                flatpak-wrapper))
            "calibredb")
        calibre-libraries
        `(("Library" . ,(expand-file-name "~/Documents/Library")))))

(provide 'misc/documents)

;;; documents.el ends here
