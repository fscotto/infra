;;; keybindings.el -*- lexical-binding: t; -*-

;;;; Global / Core

(global-set-key (kbd "C-x C-b") #'ibuffer)
(global-set-key (kbd "C-<return>") 'company-complete)
(global-set-key (kbd "M-n f") #'flyspell-buffer)

(defvar fscotto/leader-map (make-sparse-keymap)
  "Keymap per comandi sotto C-c.")

(define-key global-map (kbd "C-c") fscotto/leader-map)

;;;; Org

(autoload 'org-agenda "org" nil t)
(autoload 'org-capture "org-capture" nil t)

(define-key fscotto/leader-map (kbd "a") #'org-agenda)
(define-key fscotto/leader-map (kbd "c") #'org-capture)

;;;; Git / Magit
(defun fscotto/enable-magit-keymap ()
  "Enable Git keybindings if current buffer is inside a Git repository."
  (when (and (require 'magit nil 'noerror)
             (magit-toplevel))
    (local-set-key (kbd "C-c g") fscotto/git-map)))

(defvar fscotto/git-map (make-sparse-keymap)
  "Keymap for Git commands under C-c g.")

(add-hook 'find-file-hook #'fscotto/enable-magit-keymap)
(add-hook 'prog-mode-hook #'fscotto/enable-magit-keymap)
(add-hook 'conf-mode-hook #'fscotto/enable-magit-keymap)

;; autoload: il tasto carica magit
(autoload 'magit-status "magit" nil t)
(autoload 'magit-branch "magit" nil t)
(autoload 'magit-commit "magit" nil t)
(autoload 'magit-push "magit" nil t)
(autoload 'magit-fetch "magit" nil t)
(global-set-key (kbd "C-x g") #'magit-status)

;; keybinding (sempre definite nella mappa)
(define-key fscotto/git-map (kbd "s") #'magit-status)
(define-key fscotto/git-map (kbd "b") #'magit-branch)
(define-key fscotto/git-map (kbd "c") #'magit-commit)
(define-key fscotto/git-map (kbd "p") #'magit-push)
(define-key fscotto/git-map (kbd "f") #'magit-fetch)

;;;; Open / Tools
(defvar fscotto/open (make-sparse-keymap))
(define-key fscotto/leader-map (kbd "o") fscotto/open)

;; -------- vterm --------
(autoload 'multi-vterm "multi-vterm" nil t)
(define-key fscotto/open (kbd "T") #'fscotto/home-multi-vterm)

(with-eval-after-load 'vterm
  (define-key vterm-mode-map (kbd "C-c C-t") #'vterm-copy-mode))

;; -------- elfeed --------
(autoload 'elfeed "elfeed" nil t)
(define-key fscotto/open (kbd "f") #'fscotto/elfeed-load-db-and-open)

;; -------- gptel --------
(autoload 'gptel "gptel" nil t)
(define-key fscotto/open (kbd "l") #'gptel)

;; -------- dirvish --------
(autoload 'dirvish-dwim "dirvish" nil t)
(define-key fscotto/open (kbd "d") #'dirvish-dwim)

;; -------- ztree --------
(autoload 'ztree-diff "ztree" nil t)
(define-key fscotto/open (kbd "z") #'ztree-diff)

;;;; Elfeed mode maps
(with-eval-after-load 'elfeed
  (define-key elfeed-search-mode-map (kbd "w") #'elfeed-search-yank)
  (define-key elfeed-search-mode-map (kbd "R") #'elfeed-update)
  (define-key elfeed-search-mode-map (kbd "q") #'elfeed-kill-buffer)

  (define-key elfeed-show-mode-map (kbd "S") #'elfeed-show-new-live-search)
  (define-key elfeed-show-mode-map (kbd "f") #'elfeed-show-fetch-full-text)
  (define-key elfeed-show-mode-map (kbd "w") #'elfeed-show-yank))

;;;; hl-todo
(with-eval-after-load 'hl-todo
  (define-key hl-todo-mode-map (kbd "C-t p") #'hl-todo-previous)
  (define-key hl-todo-mode-map (kbd "C-t n") #'hl-todo-next)
  (define-key hl-todo-mode-map (kbd "C-t o") #'hl-todo-occur)
  (define-key hl-todo-mode-map (kbd "C-t i") #'hl-todo-insert))

;; Projectile keybindings
(define-key fscotto/leader-map (kbd "p") 'projectile-command-map)

(with-eval-after-load 'projectile
  (define-key projectile-command-map (kbd "v") #'fscotto/project-multi-vterm)
  (define-key projectile-command-map (kbd "V") nil)
  (define-key projectile-command-map (kbd "x") #'fscotto/project-external-terminal)
  (define-key projectile-command-map (kbd "a") #'fscotto/project-agent-dwim)
  (define-key projectile-command-map (kbd "A") #'fscotto/project-agent-session)
  (define-key projectile-command-map (kbd "g") #'fscotto/project-magit-status))

;;;; LSP
(defvar fscotto/lsp-map (make-sparse-keymap))

(autoload 'lsp-find-definition "lsp-mode" nil t)
(autoload 'lsp-find-type-definition "lsp-mode" nil t)
(autoload 'lsp-find-implementation "lsp-mode" nil t)
(autoload 'lsp-execute-code-action "lsp-mode" nil t)
(autoload 'lsp-rename "lsp-mode" nil t)
(autoload 'lsp-format-buffer "lsp-mode" nil t)
(autoload 'lsp-restart-workspace "lsp-mode" nil t)

(autoload 'consult-lsp-symbols "consult-lsp" nil t)
(autoload 'consult-lsp-diagnostics "consult-lsp" nil t)

(define-key fscotto/lsp-map (kbd "s") #'consult-lsp-symbols)
(define-key fscotto/lsp-map (kbd "e") #'consult-lsp-diagnostics)
(define-key fscotto/lsp-map (kbd "d") #'lsp-find-definition)
(define-key fscotto/lsp-map (kbd "D") #'lsp-find-type-definition)
(define-key fscotto/lsp-map (kbd "i") #'lsp-find-implementation)
(define-key fscotto/lsp-map (kbd "a") #'lsp-execute-code-action)
(define-key fscotto/lsp-map (kbd "r") #'lsp-rename)
(define-key fscotto/lsp-map (kbd "f") #'lsp-format-buffer)
(define-key fscotto/lsp-map (kbd "R") #'lsp-restart-workspace)

(defun fscotto/enable-lsp-keymap ()
  "Enable LSP keybindings if LSP is active in the current buffer."
  (when (and (bound-and-true-p lsp-mode)
             (lsp-workspaces))
    (local-set-key (kbd "C-c l") fscotto/lsp-map)))

(add-hook 'lsp-mode-hook #'fscotto/enable-lsp-keymap)
(add-hook 'lsp-after-initialize-hook #'fscotto/enable-lsp-keymap)
(add-hook 'lsp-after-open-hook #'fscotto/enable-lsp-keymap)

;;;; DAP
(defvar fscotto/dap-map (make-sparse-keymap)
  "Keymap for DAP commands under C-c d.")

(autoload 'dap-debug "dap-mode" nil t)
(autoload 'dap-breakpoint-toggle "dap-mode" nil t)
(autoload 'dap-continue "dap-mode" nil t)
(autoload 'dap-next "dap-mode" nil t)
(autoload 'dap-step-in "dap-mode" nil t)
(autoload 'dap-step-out "dap-mode" nil t)
(autoload 'dap-restart-frame "dap-mode" nil t)
(autoload 'dap-disconnect "dap-mode" nil t)

(define-key fscotto/dap-map (kbd "d") #'dap-debug)
(define-key fscotto/dap-map (kbd "b") #'dap-breakpoint-toggle)
(define-key fscotto/dap-map (kbd "c") #'dap-continue)
(define-key fscotto/dap-map (kbd "n") #'dap-next)
(define-key fscotto/dap-map (kbd "i") #'dap-step-in)
(define-key fscotto/dap-map (kbd "o") #'dap-step-out)
(define-key fscotto/dap-map (kbd "r") #'dap-restart-frame)
(define-key fscotto/dap-map (kbd "q") #'dap-disconnect)

(defun fscotto/enable-dap-keymap ()
  "Enable DAP keybindings if dap-mode is active in the current buffer."
  (when (bound-and-true-p dap-mode)
    (local-set-key (kbd "C-c d") fscotto/dap-map)))

(add-hook 'dap-mode-hook #'fscotto/enable-dap-keymap)
(add-hook 'dap-session-created-hook #'fscotto/enable-dap-keymap)
(add-hook 'dap-terminated-hook #'fscotto/enable-dap-keymap)

;;;; Go

(with-eval-after-load 'go-ts-mode
  (define-key go-ts-mode-map (kbd "C-c m t") #'fscotto/go-mod-tidy)
  (define-key go-ts-mode-map (kbd "C-c m d") #'fscotto/go-mod-download)
  (define-key go-ts-mode-map (kbd "C-c t p") #'fscotto/go-test-package)
  (define-key go-ts-mode-map (kbd "C-c t a") #'fscotto/go-test-module)
  (define-key go-ts-mode-map (kbd "C-c t t") #'fscotto/go-test-current-test)
  (define-key go-ts-mode-map (kbd "C-c d t") #'dap-debug))

(provide 'core/keybindings)

;;; keybindings.el ends here
