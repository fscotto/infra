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

(defvar-local fscotto/vterm-font-cookie nil
  "Face remap cookie used to set a custom font in vterm buffers.")

(defun fscotto/apply-vterm-font ()
  "Use Hack Nerd Font only inside vterm buffers."
  (when fscotto/vterm-font-cookie
    (face-remap-remove-relative fscotto/vterm-font-cookie))
  (setq fscotto/vterm-font-cookie
        (face-remap-add-relative
         'default
         '(:family "Hack Nerd Font" :height 120 :weight regular))))

(use-package vterm
  :ensure t
  :hook (vterm-mode . fscotto/apply-vterm-font))

(use-package multi-vterm
  :ensure t
  :after vterm
  :commands (multi-vterm multi-vterm-next multi-vterm-prev))

(provide 'terminal)

;;; terminal.el ends here
