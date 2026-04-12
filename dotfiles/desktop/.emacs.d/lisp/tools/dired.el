;;; dired.el -*- lexical-binding: t; -*-

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :config
  (setq delete-by-moving-to-trash t
        dired-dwim-target t
        dired-kill-when-opening-new-dired-buffer t
        dired-listing-switches
        "-l --almost-all --human-readable --group-directories-first --no-group")
  (put 'dired-find-alternate-file 'disabled nil))

(use-package dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-use-header-line nil)
  (dirvish-use-mode-line nil)
  (dirvish-hide-details nil)
  (dirvish-attributes nil)
  (dirvish-large-directory-threshold 20000)
  :config
  (with-eval-after-load 'projectile
    (setq projectile-switch-project-action #'projectile-dired))
  :bind
  (:map dirvish-mode-map
        ("?" . dirvish-dispatch)
        ("TAB" . dirvish-subtree-toggle)
        ("s" . dirvish-quicksort)
        ("h" . dired-up-directory)))

(provide 'tools/dired)

;;; dired.el ends here
