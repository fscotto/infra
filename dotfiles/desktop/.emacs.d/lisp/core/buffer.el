;;; buffer.el --- Buffer management -*- lexical-binding: t; -*-

(require 'use-package)

(use-package ibuffer
  :ensure t)

(use-package ibuffer-tramp
  :ensure t)

(use-package ibuffer-vc
  :ensure t)

(global-set-key (kbd "C-x C-b") #'ibuffer)

(provide 'core/buffer)
