;;; markdown.el -*- lexical-binding: t; -*-

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" . gfm-mode)
  :config
  (setq markdown-fontify-code-blocks-natively t)
  (setq markdown-live-preview-mode t))

(use-package markdown-toc
  :ensure t)

(provide 'lang/markdown)

;;; markdown.el ends here
