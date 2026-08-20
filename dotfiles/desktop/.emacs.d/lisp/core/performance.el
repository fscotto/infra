;;; performance.el --- Conservative startup settings -*- lexical-binding: t; -*-

(defvar fscotto/gc-cons-threshold-orig gc-cons-threshold)
(defvar fscotto/file-name-handler-alist-orig file-name-handler-alist)
(setq gc-cons-threshold (* 50 1000 1000)
      file-name-handler-alist nil
      inhibit-compacting-font-caches t)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold fscotto/gc-cons-threshold-orig
                  file-name-handler-alist fscotto/file-name-handler-alist-orig)
            (garbage-collect)))

(provide 'core/performance)
