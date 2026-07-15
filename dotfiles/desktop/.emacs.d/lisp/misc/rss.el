;;; rss.el -*-

(use-package elfeed
  :ensure t
  :config
  (defun elfeed-play-with-mpv ()
    "Open the current elfeed entry link with mpv."
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
  (define-key elfeed-search-mode-map (kbd "v") #'elfeed-play-with-mpv)
  (define-key elfeed-show-mode-map   (kbd "v") #'elfeed-play-with-mpv)
  :custom
  (elfeed-enclosure-default-dir "~/Downloads/")
  (elfeed-search-remain-on-entry t)
  (elfeed-search-title-max-width 100)
  (elfeed-search-title-min-width 30)
  (elfeed-search-trailing-width 25)
  (elfeed-show-truncate-long-urls t)
  (elfeed-sort-order 'descending)
  (elfeed-search-filter "+unread")
  :hook
  (elfeed-show-mode . visual-line-mode))

(use-package evil-collection
  :ensure t
  :after (evil elfeed)
  :config
  ;; Enable Vim-style keybindings only for elfeed (search + entry views),
  ;; leaving the rest of the configuration on evil's defaults.
  (evil-collection-init (list 'elfeed))
  ;; Restore the custom "v" -> mpv binding, which evil's normal-state visual
  ;; selection would otherwise shadow inside elfeed buffers.
  (evil-collection-define-key 'normal 'elfeed-search-mode-map
    "v" #'elfeed-play-with-mpv)
  (evil-collection-define-key 'normal 'elfeed-show-mode-map
    "v" #'elfeed-play-with-mpv))

(use-package elfeed-org
  :ensure t
  :after elfeed
  :custom
  ;; Optionally specify a number of files containing elfeed
  ;; configuration. If not set then the location below is used.
  ;; Note: The customize interface is also supported.
  (rmh-elfeed-org-files (list "~/.emacs.d/elfeed.org")))

(with-eval-after-load 'elfeed
  (elfeed-org))

