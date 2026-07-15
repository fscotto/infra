(message "Welcome to Emacs")
(message "Loading user configuration...")
(message "Emacs profile: %s" fscotto/emacs-profile)

;;=====================================================================================
;; Load modules
;;=====================================================================================
(fscotto/load-modules
  ;; Core
  'core/packages
  'core/ui
  'core/performance
  'core/editor
  'core/keybindings
  'core/modal
  'core/buffer

  ;; Tools
  'tools/completion
  'tools/dired
  'tools/project
  'tools/spell
  'tools/tramp
  'tools/lsp
  'tools/dap
  'tools/treesitter

  ;; Languages
  'lang/c
  'lang/docker
  'lang/golang
  'lang/json
  'lang/markdown
  'lang/org
  'lang/python
  'lang/shell
  'lang/yaml

  ;; Misc
  'misc/dashboard
  'misc/custom-functions
  'misc/doom-modeline
  'misc/which-key
  'misc/gptel
  'misc/rss
  'misc/terminal
  'misc/vcs
  'misc/documents
  'misc/i3-config
  'misc/xclip)

(message "...user configuration loaded")
