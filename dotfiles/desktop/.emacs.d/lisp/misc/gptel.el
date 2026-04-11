;;; gptel.el -*- lexical-binding: t; -*-

(use-package gptel
  :ensure t
  :commands (gptel gptel-send gptel-rewrite)
  :config
  (setq gptel-backend
        (gptel-make-ollama
         "Ollama"
         :host "localhost:11434"
         :stream t))
  ;; Set `gptel-model' after installing a local Ollama model.
  )

(provide 'fscotto-gptel)

;;; gptel.el ends here
