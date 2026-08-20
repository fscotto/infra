;;; completion.el --- Completion for writing -*- lexical-binding: t; -*-

(require 'use-package)

(use-package ivy
  :ensure t
  :config
  (ivy-mode 1))

(use-package consult
  :ensure t
  :defer t)

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-pcm-leading-wildcard t)
  :config
  (setq ivy-re-builders-alist '((t . orderless-ivy-re-builder)))
  (add-to-list 'ivy-highlight-functions-alist
               '(orderless-ivy-re-builder . orderless-ivy-re-builder-highlight)))

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode))

(use-package smartparens
  :ensure t
  :hook (text-mode . smartparens-mode)
  :config
  (require 'smartparens-config))

(provide 'tools/completion)
