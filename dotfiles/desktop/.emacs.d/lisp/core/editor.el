;;; core-editor

(require 'ansi-color)

(setq standard-indent 4)
(setq tab-stop-list nil)
(setq indent-tabs-mode nil)

;; Setting variables
(setq vc-follow-symlinks 't)
(setq vc-handled-backends nil)
(prefer-coding-system 'utf-8-unix)
(setq custom-file (null-device))

(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

(provide 'editor)

;;; editor.el ends here
