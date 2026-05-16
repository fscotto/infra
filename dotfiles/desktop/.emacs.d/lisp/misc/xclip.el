;;; misc-xclip.el  -*- lexical-binding: t; -*-

(use-package xclip
  :ensure t
  :config
  (xclip-mode t)
  (setq xclip-method 'xclip))

(provide 'xclip)

;;; xclip.el ends here
