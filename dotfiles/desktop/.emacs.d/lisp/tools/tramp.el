;;; tramp.el -*- lexical-binding: t; -*-

(use-package tramp
  :config
  (setq tramp-use-ssh-controlmaster-options t)
  (setq tramp-chunksize 500)
  (setq tramp-verbose 0)
  (setq tramp-gvfs-wget "wget --quiet")
  (setq tramp-cache-read-persistent-cache t))

(provide 'tools/tramp)

;;; tramp.el ends here
