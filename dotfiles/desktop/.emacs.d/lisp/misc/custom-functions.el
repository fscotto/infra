;;functions to support syncing .elfeed between machines
;;makes sure elfeed reads index from disk before launching
(defun fscotto/elfeed-load-db-and-open ()
  "Wrapper to load the elfeed db from disk before opening URL https://pragmaticemacs.wordpress.com/2016/08/17/read-your-rss-feeds-in-emacs-with-elfeed/
  Created: 2016-08-17
  Updated: 2025-06-13"
  (interactive)
  (elfeed)
  (elfeed-db-load)
  ;; (elfeed-search-update--force)
  (elfeed-update)
  (elfeed-db-save))

(defun fscotto/project-root ()
  "Return projectile project root or fallback to default-directory."
  (if (featurep 'projectile)
      (or (projectile-project-root) default-directory)
    default-directory))

(defun fscotto/project-vterm ()
  "Open vterm in project root."
  (interactive)
  (let ((default-directory (fscotto/project-root)))
    (vterm)))

(defun fscotto/open-multi-vterm-in (directory)
  "Open a new multi-vterm buffer in DIRECTORY."
  (let ((default-directory (file-name-as-directory directory)))
    (multi-vterm)))

(defun fscotto/home-multi-vterm ()
  "Open a new multi-vterm buffer in HOME."
  (interactive)
  (fscotto/open-multi-vterm-in (expand-file-name "~/")))

(defun fscotto/project-multi-vterm ()
  "Open a new multi-vterm buffer in project root."
  (interactive)
  (fscotto/open-multi-vterm-in (fscotto/project-root)))

(defconst fscotto/opencode-db-path
  (expand-file-name "~/.local/share/opencode/opencode.db")
  "Path to the OpenCode SQLite database.")

(defun fscotto/launch-external-terminal (&optional command directory)
  "Launch external terminal in DIRECTORY, optionally running COMMAND."
  (let* ((default-directory (file-name-as-directory (or directory (fscotto/project-root))))
         (terminal-program (or (executable-find fscotto/external-terminal-program)
                               fscotto/external-terminal-program))
         (args (append
                 (list fscotto/external-terminal-working-directory-option
                      default-directory)
                (when command
                  (append
                   (list fscotto/external-terminal-execute-option)
                   command)))))
    (unless (file-executable-p terminal-program)
      (user-error "External terminal not found: %s" fscotto/external-terminal-program))
    (apply #'start-process
           "fscotto-external-terminal"
           nil
           terminal-program
           args)))

(defun fscotto/opencode-session-candidates (directory)
  "Return OpenCode session candidates for DIRECTORY.

Each entry is a cons cell of display string and session id."
  (let ((sqlite3-program (executable-find "sqlite3"))
        (session-directory (directory-file-name (expand-file-name directory))))
    (unless sqlite3-program
      (user-error "sqlite3 not found"))
    (unless (file-exists-p fscotto/opencode-db-path)
      (user-error "OpenCode database not found: %s" fscotto/opencode-db-path))
    (mapcar
     (lambda (line)
       (pcase-let* ((fields (split-string line "\t"))
                    (`(,session-id ,title ,updated-at) fields)
                    (title (if (and title (not (string= title "")))
                               title
                             "Untitled session"))
                    (updated-seconds (/ (string-to-number updated-at) 1000))
                    (updated-label (format-time-string "%Y-%m-%d %H:%M"
                                                       (seconds-to-time updated-seconds)))
                    (short-id (if (> (length session-id) 12)
                                  (substring session-id 0 12)
                                session-id)))
         (cons (format "%s | %s | %s" title updated-label short-id)
               session-id)))
     (process-lines
      sqlite3-program
      "-tabs"
      "-noheader"
      fscotto/opencode-db-path
      (format (concat
               "select id, title, time_updated "
               "from session "
               "where directory = '%s' and time_archived is null "
               "order by time_updated desc;")
              (replace-regexp-in-string "'" "''" session-directory))))))

(defun fscotto/project-opencode-session ()
  "Resume a saved OpenCode session for the current project."
  (interactive)
  (let* ((project-directory (fscotto/project-root))
         (candidates (fscotto/opencode-session-candidates project-directory)))
    (unless candidates
      (user-error "No OpenCode sessions found for %s" project-directory))
    (let* ((selection (completing-read "OpenCode session: " candidates nil t))
           (session-id (cdr (assoc selection candidates))))
      (fscotto/launch-external-terminal (list "opencode" "--session" session-id)
                                        project-directory))))

(defun fscotto/project-external-terminal ()
  "Open the external terminal in project root."
  (interactive)
  (fscotto/launch-external-terminal))

(defun fscotto/project-opencode ()
  "Open the external terminal in project root and run opencode."
  (interactive)
  (fscotto/launch-external-terminal '("opencode")))

(defun fscotto/project-magit-status ()
  "Open magit-status in project root."
  (interactive)
  (let ((default-directory (fscotto/project-root)))
    (magit-status)))

(defun fscotto/magit-dispatch ()
  "Load Magit if necessary and open magit-dispatch."
  (interactive)
  (require 'magit)
  (call-interactively #'magit-dispatch))

(defun fscotto/disable-c-formatting ()
  (setq-local lsp-enable-on-type-formatting nil))

;; Golang development support functions
(defun fscotto/go-format-on-save ()
  "Format Go buffers on save using gofmt."
  (add-hook 'before-save-hook #'lsp-format-buffer nil t))

(defun fscotto/go-mod-tidy ()
  "Esegue go mod tidy nella root del progetto."
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (compile "go mod tidy")))

(defun fscotto/go-mod-download ()
  "Scarica i moduli Go."
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (compile "go mod download")))

(defun fscotto/go-mod-after-save ()
  (when (and (eq major-mode 'go-mod-ts-mode)
             (lsp-workspaces))
    (lsp-restart-workspace)))

(defun fscotto/go-test-package ()
  "Run `go test` in the current package."
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (compile "go test")))

(defun fscotto/go-test-module ()
  "Run `go test ./...` in the current Go module."
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (compile "go test ./...")))

(defun fscotto/go-test-current-test ()
  "Run `go test -run` for the test at point."
  (interactive)
  (let* ((test-name (thing-at-point 'symbol t))
         (default-directory (project-root (project-current t))))
    (unless test-name
      (user-error "No test name at point"))
    (compile (format "go test -run '^%s$'" test-name))))

(defun fscotto/go-test-at-point ()
  "Return Go test name at point."
  (let ((sym (thing-at-point 'symbol t)))
    (unless (and sym (string-prefix-p "Test" sym))
      (user-error "No Go test at point"))
    sym))
