;;; pdf.el -*- lexical-binding: t; -*-

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

(provide 'misc/pdf)

;;; pdf.el ends here
