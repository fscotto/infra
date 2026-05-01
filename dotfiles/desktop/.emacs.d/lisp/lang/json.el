;;; json.el -*- lexical-binding: t -*-

(defun fscotto/json-maybe-start-lsp ()
  "Start LSP for JSON buffers when lsp-mode is available."
  (when (fboundp 'lsp-deferred)
    (lsp-deferred)))

(use-package json-mode
  :ensure t
  :mode
  (("\\.json\\'" . json-mode)
   ("\\.jsonc\\'" . json-mode))
  :hook
  (json-mode . fscotto/json-maybe-start-lsp))

(with-eval-after-load 'json-ts-mode
  (add-hook 'json-ts-mode-hook #'fscotto/json-maybe-start-lsp))

(with-eval-after-load 'jsonc-mode
  (add-hook 'jsonc-mode-hook #'fscotto/json-maybe-start-lsp))

(provide 'json)

;;; json.el ends here
