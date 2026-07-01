;;; modal.el --- Vim motions for the desktop Emacs profile -*- lexical-binding: t; -*-

(use-package evil
  :ensure t
  :init
  (setq evil-want-C-u-scroll t
        evil-want-C-i-jump nil
        evil-undo-system 'undo-redo)
  :config
  (evil-mode 1)
  (evil-define-key '(normal visual motion) 'global
    (kbd "SPC") fscotto/leader-map))

(provide 'modal)

;;; modal.el ends here
