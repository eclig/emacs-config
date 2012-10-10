;;; pcomplete-bash.el --- pcomplete completion using BASH's `compgen'

;; Copyright (C) 2012  Emilio C. Lopes

;; Author: Emilio C. Lopes <eclig@gmx.net>
;; Keywords: processes, convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Caveats:
;;   * `shell-prompt-pattern' should be set to a sensible value
;;   * Bash option `extglob' should be set ("shopt -s extglob")

;;; Code:
(defun pcmpl-bash-complete-command ()
  "Completion function for Bash command names.
Uses Bash's builtin `compgen' to get a list of possible commands."
  (let ((cmd (or (pcomplete-arg 'first) "")))
    (when (> (length cmd) 0)        ; do not complete an empty command
      (pcomplete-here* (pcomplete-uniqify-list (comint-redirect-results-list
                                                (format (if (memq system-type '(ms-dos windows-nt cygwin)) 
                                                            "compgen -X '*.@(dll|ime)' -c '%s'"
                                                          "compgen -c '%s'")
                                                        cmd) "^\\(.+\\)$" 1))))))

(defun pcmpl-bash-command-name ()
  (let ((cmd (file-name-nondirectory (pcomplete-arg 'first))))
    (if (memq system-type '(ms-dos windows-nt cygwin))
	(file-name-sans-extension cmd)
      cmd)))

(defun pcmpl-bash-default-completion-function ()
  (while (pcomplete-here (pcomplete-entries))))

;; (defun pcmpl-bash-environment-variable-completion ()
;;   "Completion data for an environment variable at point, if any."
;;   (let ((var (nth pcomplete-index pcomplete-args)))
;;     (when (and (not (zerop (length var))) (eq (aref var 0) ?$))
;;       (pcomplete-here* (pcomplete-uniqify-list (comint-redirect-results-list (format "compgen -P \\$ -v %s" (substring var 1)) "^\\(.+\\)$" 1))))))

(defun pcmpl-bash-setup ()
  (set (make-local-variable 'pcomplete-command-completion-function) #'pcmpl-bash-complete-command)
  (set (make-local-variable 'pcomplete-command-name-function) #'pcmpl-bash-command-name)
  (set (make-local-variable 'pcomplete-default-completion-function) #'pcmpl-bash-default-completion-function))

(provide 'pcomplete-bash)
;;; pcomplete-bash.el ends here