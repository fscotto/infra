;;; gptel.el -*- lexical-binding: t; -*-

(use-package gptel
  :ensure t
  :commands (gptel gptel-send gptel-rewrite)
  :config
  (setq gptel-model 'qwen3.5:397b)
  (setq gptel-backend
        (gptel-make-ollama
         "Ollama Cloud"
         :protocol "https"
         :host "ollama.com"
         :endpoint "/api/chat"
         :models '(qwen3.5:397b)
         :stream t
         :key (lambda () (gptel-api-key-from-auth-source "ollama.com"))
         :header
         (lambda (&optional _info)
           (when-let ((key (gptel-api-key-from-auth-source "ollama.com")))
             `(("Authorization" . ,(concat "Bearer " key))))))))

(provide 'fscotto-gptel)

;;; gptel.el ends here
