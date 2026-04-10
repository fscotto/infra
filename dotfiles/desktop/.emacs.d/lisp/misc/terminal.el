;;; terminal.el -*- lexical-binding: t; -*-

(defgroup fscotto nil
  "Personal customization group."
  :group 'applications)

(defcustom fscotto/external-terminal-program "alacritty"
  "Program used to launch external terminal windows."
  :type 'string
  :group 'fscotto)

(defcustom fscotto/external-terminal-working-directory-option "--working-directory"
  "Argument used to set the working directory for the external terminal."
  :type 'string
  :group 'fscotto)

(defcustom fscotto/external-terminal-execute-option "-e"
  "Argument used to execute a command in the external terminal."
  :type 'string
  :group 'fscotto)

(use-package vterm
  :ensure t)

(use-package multi-vterm
  :ensure t
  :after vterm
  :commands (multi-vterm multi-vterm-next multi-vterm-prev))

(provide 'terminal)

;;; terminal.el ends here
