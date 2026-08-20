(message "Loading authoring configuration...")

(fscotto/load-modules
 'core/packages
 'core/ui
 'core/performance
 'core/editor
 'core/keybindings
 'core/buffer
 'tools/spell
 'tools/completion
 'lang/org
 'authoring
 'quality-of-life
 'misc/dashboard
 'misc/which-key
 'misc/vcs
 'misc/rss)

(message "Authoring configuration loaded")
