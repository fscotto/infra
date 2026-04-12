;;; dashboard.el --- Startup dashboard -*- lexical-binding: t; -*-

;;; Commentary:

;; Show the dashboard on regular startup and on empty emacsclient frames.

(use-package dashboard
  :ensure t
  :init
  (setq dashboard-startup-banner 'logo
        dashboard-center-content t
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-items '((recents  . 8)
                          (projects . 5)))
  :config
  (dashboard-setup-startup-hook))

(defun fscotto/show-dashboard-on-client-frame ()
  "Show dashboard in an empty graphical emacsclient frame."
  (when (and (display-graphic-p)
             (string= (buffer-name (window-buffer (selected-window))) "*scratch*"))
    (require 'dashboard)
    (switch-to-buffer dashboard-buffer-name)
    (dashboard-refresh-buffer)
    (goto-char (point-min))))

(with-eval-after-load 'server
  (add-hook 'server-after-make-frame-hook #'fscotto/show-dashboard-on-client-frame))

(provide 'dashboard)

;;; misc-dashboard.el ends here
