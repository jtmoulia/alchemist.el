;;; alchemist-help.el --- Interaction with an Elixir IEx process

;; Copyright © 2014-2015 Samuel Tonini

;; Author: Samuel Tonini <tonini.samuel@gmail.com

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Interaction with an Elixir IEx process

;;; Code:

(require 'comint)

(defgroup alchemist-iex nil
  "Interaction with an Elixir IEx process."
  :prefix "alchemist-iex-"
  :group 'alchemist)

(defcustom alchemist-iex-program-name "iex"
  "The shell command for iex."
  :type 'string
  :group 'alchemist-iex)

(defvar alchemist-iex-buffer nil
  "The buffer in which the Elixir IEx process is running.")

(defvar alchemist-iex-buffer-root-name "Alchemist-IEx"
  "The root name for alchemist IEx buffers.")

(defvar alchemist-iex-mode-hook nil
  "Hook for customizing `alchemist-iex-mode'.")


(define-derived-mode alchemist-iex-mode comint-mode "Alchemist-IEx"
  "Major mode for interacting with an Elixir IEx process."
  nil "Alchemist-IEx"
  (set (make-local-variable 'comint-prompt-regexp)
       "^iex(\\([0-9]+\\|[a-zA-Z_@]+\\))> ")
  (set (make-local-variable 'comint-input-autoexpand) nil))

(defun alchemist-iex-command (arg)
  (split-string-and-unquote
   (if (null arg) alchemist-iex-program-name
     (read-string "Command to run Elixir IEx: " (concat alchemist-iex-program-name arg)))))

(defun alchemist-iex--comint-name (name)
  (if name (concat alchemist-iex-buffer-root-name "-" name)
    alchemist-iex-buffer-root-name))

(defun alchemist-iex-start-process (command &optional name)
  "Start an IEX process.
With universal prefix \\[universal-argument], prompts for a COMMAND,
otherwise uses `alchemist-iex-program-name'.
It runs the hook `alchemist-iex-mode-hook' after starting the process and
setting up the IEx buffer."
  (interactive (list (alchemist-iex-command current-prefix-arg)))
  (setq alchemist-iex-buffer
        (apply 'make-comint (alchemist-iex--comint-name name)
               (car command) nil (cdr command)))
  (with-current-buffer alchemist-iex-buffer
    (alchemist-iex-mode)
    (run-hooks 'alchemist-iex-mode-hook)))

(defun alchemist-iex-process (&optional arg name)
  (or (if (buffer-live-p alchemist-iex-buffer)
          (get-buffer-process alchemist-iex-buffer))
      (progn
        (let ((current-prefix-arg arg))
          (call-interactively 'alchemist-iex-start-process))
        (alchemist-iex-process arg))))

(defun alchemist-iex--remove-newlines (string)
  (replace-regexp-in-string "\n" " " string))

(defun alchemist-iex-send-last-sexp ()
  "Send the previous sexp to the inferior IEx process."
  (interactive)
  (alchemist-iex-send-region (save-excursion (backward-sexp) (point)) (point)))

(defun alchemist-iex-send-current-line ()
  "Sends the current line to the IEx process."
  (interactive)
  (let ((str (thing-at-point 'line)))
    (alchemist-iex--send-command (alchemist-iex-process) str)))

(defun alchemist-iex-send-current-line-and-go ()
  "Sends the current line to the inferior IEx process
and jump to the buffer."
  (interactive)
  (call-interactively 'alchemist-iex-send-current-line)
  (pop-to-buffer (process-buffer (alchemist-iex-process))))

(defun alchemist-iex-send-region-and-go ()
  "Sends the marked region to the inferior IEx process
and jump to the buffer."
  (interactive)
  (call-interactively 'alchemist-iex-send-region)
  (pop-to-buffer (process-buffer (alchemist-iex-process))))

(defun alchemist-iex-send-region (beg end)
  "Sends the marked region to the IEx process."
  (interactive (list (point) (mark)))
  (unless (and beg end)
    (error "The mark is not set now, so there is no region"))
  (let* ((region (buffer-substring-no-properties beg end)))
    (alchemist-iex--send-command (alchemist-iex-process) region)))

(defun alchemist-iex-compile-this-buffer ()
  "Compiles the current buffer in the IEx process."
  (interactive)
  (let ((str (format "c(\"%s\")" (buffer-file-name))))
    (alchemist-iex--send-command (alchemist-iex-process) str)))

(defun alchemist-iex-recompile-this-buffer ()
  "Recompiles and reloads the current buffer in the IEx process."
  (interactive)
  (let ((str (format "r(\"%s\")" (buffer-file-name))))
    (alchemist-iex--send-command (alchemist-iex-process) str)))

(defun alchemist-iex--send-command (proc str)
  (let ((str-no-newline (concat (alchemist-iex--remove-newlines str) "\n"))
        (str (concat str "\n")))
    (with-current-buffer (process-buffer proc)
      (goto-char (process-mark proc))
      (insert-before-markers str)
      (move-marker comint-last-input-end (point))
      (comint-send-string proc str-no-newline))))

(defun alchemist-iex-clear-buffer ()
  "Clear the current iex process buffer."
  (interactive)
  (let ((comint-buffer-maximum-size 0))
    (comint-truncate-buffer)))

;;;###autoload
(defalias 'run-elixir 'alchemist-iex-run)
(defalias 'inferior-elixir 'alchemist-iex-run)

;;;###autoload
(defun alchemist-iex-run (&optional arg)
  "Start an IEx process.
Show the IEx buffer if an IEx process is already run."
  (interactive "P")
  (let ((proc (alchemist-iex-process arg)))
    (pop-to-buffer (process-buffer proc))))

;;;###autoload
(defun alchemist-iex-project-run ()
  "Start an IEx process with mix 'iex -S mix' in the
context of an Elixir project.
Show the IEx buffer if an IEx process is already run."
  (interactive)
  (let ((old-directory default-directory))
  (if (alchemist-project-p)
      (progn
        (alchemist-project--establish-root-directory)
        (let ((proc (alchemist-iex-process " -S mix" (alchemist-project-name))))
          (cd old-directory)
          (pop-to-buffer (process-buffer proc))))
    (message "No mix.exs file available. Please use `alchemist-iex-run' instead."))))

(provide 'alchemist-iex)

;;; alchemist-iex.el ends here
