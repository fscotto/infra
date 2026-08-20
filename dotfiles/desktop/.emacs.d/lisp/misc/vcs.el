;;; vcs.el --- Optional Git interface -*- lexical-binding: t; -*-

(autoload 'magit-status "magit" nil t)
(global-set-key (kbd "C-x g") #'magit-status)

(provide 'misc/vcs)
