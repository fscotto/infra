;;; gptel.el -*- lexical-binding: t; -*-

(use-package gptel
  :ensure t
  :commands (gptel gptel-send gptel-rewrite)
  :config
  (let ((private-config
         (expand-file-name "lisp/misc/gptel-private.el" user-emacs-directory)))
    (when (file-readable-p private-config)
      (load private-config nil 'nomessage))))

(provide 'fscotto-gptel)

;;; gptel.el ends here
