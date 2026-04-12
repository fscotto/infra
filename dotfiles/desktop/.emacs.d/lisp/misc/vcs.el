(use-package magit
  :ensure t
  :commands (magit-status magit-log)
  :init
  ;; Entry point principale
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1)
  :config
  ;; Performance & UX
  (setq magit-refresh-status-buffer nil)
  (setq magit-repository-directories
	'(("~/Projects" . 2)
	  ("~/Work" . 2))))

(use-package vdiff
  :ensure t
  :commands (vdiff-current-file vdiff-files vdiff-merge-conflict)
  :custom
  (vdiff-lock-scrolling t)
  (vdiff-auto-refine t))

(use-package vdiff-magit
  :ensure t
  :after (magit vdiff)
  :commands (vdiff-magit vdiff-magit-dwim)
  :custom
  (vdiff-magit-use-ediff-for-merges nil)
  :config
  (define-key magit-mode-map "e" #'vdiff-magit-dwim)
  (define-key magit-mode-map "E" #'vdiff-magit)
  (transient-suffix-put 'magit-dispatch "e" :description "vdiff (dwim)")
  (transient-suffix-put 'magit-dispatch "e" :command #'vdiff-magit-dwim)
  (transient-suffix-put 'magit-dispatch "E" :description "vdiff")
  (transient-suffix-put 'magit-dispatch "E" :command #'vdiff-magit))

(use-package ztree
  :ensure t
  :commands (ztree-diff ztree-dir))

(provide 'vcs)

;;; vcs.el ends here
