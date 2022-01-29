;;; plancat.el --- Plan.cat interface -*- lexical-binding: t; -*-

;;; Commentary:

;; https://plan.cat/

;;; Code:

(defgroup plancat nil
  "Customization group for updating plan.cat."
  :group 'network
  :group 'applications)

(defcustom plancat-user nil
  "Plan.cat username.")

(defcustom plancat-host "plan.cat"
  "Plan.cat host.")

(defcustom plancat-pass nil
  "Plan.cat password.")

(defcustom plancat-buffer "*plan.cat*"
  "The name to give the plan.cat buffer.")

(defun plancat-auth (&optional user)
  "Generate an authentication string for USER."
  (let ((pass (if-let* ((auth (auth-source-search
                               :host plancat-host
                               :user plancat-user
                               :require '(:user :secret)))
                        (secret (plist-get (car auth) :secret)))
                  (funcall secret)
                plancat-pasps)))
    (base64-encode-string (concat (or user plancat-user)
                                  ":" pass))))

(+defvar plancat-map
    (let ((map (make-sparse-keymap)))
      (define-key map (kbd "C-c C-c") #'plancat-send)
      (define-key map (kbd "C-c C-k") #'plancat-cancel)
      map)
  "Keymap for `plancat-mode'.")

(define-minor-mode plancat-mode
  "Update plan.cat."
  :lighter " plan.cat"
  :keymap plancat-map)

(defun plan.cat ()
  (interactive)
  (let ((buf (get-buffer-create plancat-buffer))
        (cur (with-current-buffer
                 (url-retrieve-synchronously
                  (format "https://%s/~%s"
                          plancat-host
                          plancat-user))
               (buffer-substring-no-properties
                (point-min) (point-max)))))
    (with-current-buffer buf
      (erase-buffer)
      (insert (replace-regexp-in-string (rx bos
                                            (+? anything)
                                            "\n\n")
                                        ""
                                        cur))
      (goto-char (point-min))
      (text-mode)
      (plancat-mode +1))
    (switch-to-buffer-other-window buf)))

(defun plancat-send ()
  "Send the current buffer to plan.cat."
  (interactive)
  (with-current-buffer plancat-buffer
    (let ((url-request-method "POST")
          (url-request-data
           (concat "plan=" (buffer-substring-no-properties
                            (point-min) (point-max))))
          (url-request-extra-headers
           `(("Content-Type"
              . "application/x-www-form-urlencoded")
             ("Authorization"
              . ,(concat "Basic " (plancat-auth plancat-user))))))
      (with-temp-buffer
        (url-retrieve (format "https://%s/stdin" plancat-host)
                      (lambda (status)
                        (if-let (err (plist-get status :error))
                            (user-error
                             "Plan.cat submission errored: %S"
                             err)
                          (message "https://%s/~%s/.plan updated!"
                                   plancat-host
                                   plancat-user)
                          (plancat-cancel))))))))

(defun plancat-cancel ()
  "Cancel updating plan.cat."
  (interactive)
  (when (get-buffer plancat-buffer)
    (with-current-buffer plancat-buffer
      (kill-buffer-and-window))))

(provide 'plancat)
;;; plancat.el ends here