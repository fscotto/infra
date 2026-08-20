;;; rss.el --- Elfeed configuration -*- lexical-binding: t; -*-

(require 'use-package)

(use-package elfeed
  :ensure t
  :commands elfeed
  :bind ("C-c r" . elfeed)
  :config
  (defun elfeed-play-with-mpv ()
    "Open the current Elfeed entry link with mpv."
    (interactive)
    (let* ((entry (if (eq major-mode 'elfeed-show-mode)
                      elfeed-show-entry
                    (elfeed-search-selected :ignore-region)))
           (url (and entry (elfeed-entry-link entry))))
      (if url
          (progn
            (message "Opening with mpv: %s" url)
            (start-process "mpv" nil "mpv" url))
        (message "No URL found"))))

  (setq elfeed-enclosure-default-dir "~/Downloads/"
        elfeed-search-remain-on-entry t
        elfeed-search-title-max-width 100
        elfeed-search-title-min-width 30
        elfeed-search-trailing-width 25
        elfeed-show-truncate-long-urls t
        elfeed-sort-order 'descending
        elfeed-search-filter "+unread")
  (define-key elfeed-search-mode-map (kbd "v") #'elfeed-play-with-mpv)
  (define-key elfeed-show-mode-map (kbd "v") #'elfeed-play-with-mpv)
  (add-hook 'elfeed-show-mode-hook #'visual-line-mode))

(use-package elfeed-org
  :ensure t
  :after elfeed
  :custom
  (rmh-elfeed-org-files (list (expand-file-name "elfeed.org" user-emacs-directory)))
  :config
  (elfeed-org))

(provide 'misc/rss)
