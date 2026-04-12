;;; treesitter.el -*- lexical-binding: t; -*-

(use-package treesit
  :ensure nil
  :config
  (setq treesit-font-lock-level 4))

(use-package treesit-auto
  :ensure t
  :after treesit
  :custom
  (treesit-auto-install 'prompt)
  (treesit-auto-langs '(bash c cpp dockerfile go gomod json markdown python yaml))
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(provide 'treesitter)

;;; treesitter.el ends here
