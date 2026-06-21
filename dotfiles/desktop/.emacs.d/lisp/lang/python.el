;;; python.el -*- lexical-binding: t; -*-

(require 'reformatter)

(with-eval-after-load 'project
  (add-to-list 'project-vc-extra-root-markers "pyproject.toml")
  (add-to-list 'project-vc-extra-root-markers "uv.lock")
  (add-to-list 'project-vc-extra-root-markers ".venv"))

(defun fscotto/python-project-root ()
  "Return project root for Python projects, nil otherwise."
  (when (and (featurep 'project)
             (project-current))
    (let ((root (project-root (project-current))))
      (when (or (file-exists-p (expand-file-name "pyproject.toml" root))
                (file-exists-p (expand-file-name "uv.lock" root)))
        root))))

(defun fscotto/python-project-has-uv-p ()
  "Return t if current project uses uv (pyproject.toml or uv.lock)."
  (when-let ((root (fscotto/python-project-root)))
    (or (file-exists-p (expand-file-name "uv.lock" root))
        (file-exists-p (expand-file-name "pyproject.toml" root)))))

(defun fscotto/python-project-bin (tool)
  "Return path to TOOL in .venv/bin if it exists, else nil."
  (when-let ((root (fscotto/python-project-root)))
    (let ((venv-bin (expand-file-name (concat ".venv/bin/" tool) root)))
      (when (and (file-exists-p venv-bin)
                 (file-executable-p venv-bin))
        venv-bin))))

(defun fscotto/python-activate-project-tools ()
  "Prefer tools from the project virtualenv when available."
  (when-let* ((root (fscotto/python-project-root))
              (venv-bin (expand-file-name ".venv/bin" root))
              ((file-directory-p venv-bin)))
    (make-local-variable 'exec-path)
    (add-to-list 'exec-path venv-bin)
    (setq-local process-environment (copy-sequence process-environment))
    (setenv "PATH" (concat venv-bin path-separator (getenv "PATH")))))

(defun fscotto/resolve-pylsp ()
  "Return the pylsp binary path if found, else nil.
Checks: project .venv, uv tool install path, and PATH."
  (or (fscotto/python-project-bin "pylsp")
      (let ((uv-pylsp (expand-file-name "pylsp"
                                        (concat (getenv "HOME")
                                                "/.local/share/uv/tools/python-lsp-server/bin"))))
        (when (and (file-exists-p uv-pylsp)
                   (file-executable-p uv-pylsp))
          uv-pylsp))
      (executable-find "pylsp")))

(defun fscotto/python-lsp-server-available-p ()
  "Return non-nil when a supported Python LSP server is available."
  (fscotto/resolve-pylsp))

(defun fscotto/python-ensure-lsp-server ()
  "Start Python LSP when its Ansible-managed pylsp executable is available."
  (cond
   ((not (fboundp 'lsp-deferred))
    (message "python: lsp-mode not available"))
   ((fscotto/python-lsp-server-available-p)
    (setq lsp-pylsp-server-command (fscotto/resolve-pylsp))
    (lsp-deferred))
   (t
    (message "python: pylsp not found; run the desktop Ansible profile"))))

(defun fscotto/python-maybe-start-lsp ()
  "Start Python LSP when pylsp is available."
  (fscotto/python-ensure-lsp-server))

(defun fscotto/python-setup-check-command ()
  "Use Ruff for the built-in Python check command."
  (setq-local python-check-command "ruff check"))

(reformatter-define fscotto/ruff-format
  :program (or (fscotto/python-project-bin "ruff") (executable-find "ruff"))
  :args '("format" "-")
  :lighter " ruff")

(with-eval-after-load 'python
  (add-hook 'python-mode-hook #'fscotto/python-activate-project-tools)
  (add-hook 'python-mode-hook #'fscotto/python-setup-check-command)
  (add-hook 'python-mode-hook #'fscotto/ruff-format-on-save-mode)
  (add-hook 'python-mode-hook #'fscotto/python-maybe-start-lsp))

(with-eval-after-load 'python-ts-mode
  (add-hook 'python-ts-mode-hook #'fscotto/python-activate-project-tools)
  (add-hook 'python-ts-mode-hook #'fscotto/python-setup-check-command)
  (add-hook 'python-ts-mode-hook #'fscotto/ruff-format-on-save-mode)
  (add-hook 'python-ts-mode-hook #'fscotto/python-maybe-start-lsp))

(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration '(python-mode . "python"))
  (add-to-list 'lsp-language-id-configuration '(python-ts-mode . "python"))
  (setq lsp-pylsp-server-command (fscotto/resolve-pylsp))
  (setq lsp-pylsp-plugins
        '((pycodestyle nil)
          (pyflakes nil)
          (mccabe nil)
          (autopep8 nil)
          (yapf nil)))
  (add-to-list 'lsp-disabled-clients 'pyls))

(provide 'lang/python)

;;; python.el ends here
